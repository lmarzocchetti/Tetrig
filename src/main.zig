const std = @import("std");
const rl = @import("raylib");

// Random Generator
fn curr_time() u64 {
    return @as(u64, @intCast(std.time.milliTimestamp()));
}
var rand_prng: std.Random.Xoshiro256 = undefined;
var rand_gen: std.Random = undefined;

// Constants
const COLS = 10;
const ROWS = 20;
const HIDDEN_ROWS = 2;
const TOTAL_ROWS = ROWS + HIDDEN_ROWS;
const SQUARE_SIZE = 40;
const GUI_SIZE = 300;

const Square = [2]i32;

const PieceKind = enum {
    T,
    J,
    Z,
    O,
    S,
    L,
    I,

    pub fn color(self: PieceKind) rl.Color {
        switch (self) {
            .T => return rl.Color.purple,
            .J => return rl.Color.blue,
            .Z => return rl.Color.red,
            .O => return rl.Color.yellow,
            .S => return rl.Color.green,
            .L => return rl.Color.orange,
            .I => return rl.Color.sky_blue,
        }
    }
};

const Piece = struct {
    kind: PieceKind,
    squares: [4]Square,

    /// Returns the column index of most left square of the Piece
    pub fn left_square(self: Piece) i32 {
        var min_col: i32 = 100;
        for (self.squares) |square| {
            if (square[1] < min_col) {
                min_col = square[1];
            }
        }
        return min_col;
    }

    /// Returns the column index of most right square of the Piece
    pub fn right_square(self: Piece) i32 {
        var max_col: i32 = 0;
        for (self.squares) |square| {
            if (square[1] > max_col) {
                max_col = square[1];
            }
        }
        return max_col;
    }

    /// Rotate the piece clockwise or counterclockwise based on direction (1.0 or -1.0)
    pub fn rotate(self: *Piece, direction: f32, game: Game) void {
        const DEGREE = direction * std.math.pi / 2.0;
        const origin: Square = self.squares[1];

        var rotated_points: [4]Square = undefined;

        for (self.squares, 0..) |square, i| {
            const x0: f32 = @floatFromInt(square[0] - origin[0]);
            const y0: f32 = @floatFromInt(square[1] - origin[1]);
            var x1: i32 = @intFromFloat(@round(x0 * @cos(DEGREE) - y0 * @sin(DEGREE)));
            var y1: i32 = @intFromFloat(@round(x0 * @sin(DEGREE) + y0 * @cos(DEGREE)));
            x1 += origin[0];
            y1 += origin[1];
            const points: Square = .{ x1, y1 };
            rotated_points[i] = points;

            // Control if the piece is out of bounds or touching other squares
            if (x1 < 0 or x1 >= TOTAL_ROWS or y1 < 0 or y1 >= COLS or game.touch_other_square(points)) {
                return;
            }
        }

        self.squares = rotated_points;
    }
};

const Direction = enum {
    Left,
    Right,
};

/// Struct to represent a single square in the Board. If a square is active and its type (for color)
const Slot = struct {
    active: bool,
    type: ?PieceKind,
};

/// 2D array to represent the Board
const Board = [TOTAL_ROWS][COLS]Slot;

/// Struct to represent the Game state
const Game = struct {
    board: Board,
    active_piece: Piece,
    next_piece: Piece,
    destroyed_lines: u32,

    /// Initialize the Game state with all empty slots
    pub fn init() Game {
        var board: Board = undefined;
        for (board, 0..) |rows, row| {
            for (rows, 0..) |_, col| {
                board[row][col] = .{
                    .active = false,
                    .type = null,
                };
            }
        }
        return Game{
            .board = board,
            .active_piece = Game.spawn_piece(),
            .next_piece = Game.spawn_piece(),
            .destroyed_lines = 0,
        };
    }

    /// Return a random Piece to spawn
    fn spawn_piece() Piece {
        const piece_kind_to_spawn = rand_gen.enumValue(PieceKind);
        var piece_to_spawn: Piece = undefined;
        piece_to_spawn.kind = piece_kind_to_spawn;
        switch (piece_kind_to_spawn) {
            .T => {
                piece_to_spawn.squares = .{
                    .{ 1, 5 },
                    .{ 0, 4 },
                    .{ 0, 5 },
                    .{ 0, 6 },
                };
            },
            .I => {
                piece_to_spawn.squares = .{
                    .{ 1, 4 },
                    .{ 1, 5 },
                    .{ 1, 6 },
                    .{ 1, 7 },
                };
            },
            .J => {
                piece_to_spawn.squares = .{
                    .{ 1, 4 },
                    .{ 1, 5 },
                    .{ 1, 6 },
                    .{ 0, 6 },
                };
            },
            .Z => {
                piece_to_spawn.squares = .{
                    .{ 1, 4 },
                    .{ 1, 5 },
                    .{ 0, 5 },
                    .{ 0, 6 },
                };
            },
            .O => {
                piece_to_spawn.squares = .{
                    .{ 1, 4 },
                    .{ 1, 5 },
                    .{ 0, 4 },
                    .{ 0, 5 },
                };
            },
            .S => {
                piece_to_spawn.squares = .{
                    .{ 1, 5 },
                    .{ 1, 6 },
                    .{ 0, 4 },
                    .{ 0, 5 },
                };
            },
            .L => {
                piece_to_spawn.squares = .{
                    .{ 1, 4 },
                    .{ 1, 5 },
                    .{ 1, 6 },
                    .{ 0, 4 },
                };
            },
        }
        return piece_to_spawn;
    }

    /// Check if a square is touching another square
    fn touch_other_square(self: Game, square: Square) bool {
        if (self.board[@intCast(square[0])][@intCast(square[1])].active == true) {
            return true;
        }
        return false;
    }

    fn active_piece_can_go_right(self: *Game) bool {
        const active_right = self.active_piece.right_square();
        if (active_right == COLS - 1) {
            return false;
        }

        // Check if the piece is touching other squares
        for (&self.active_piece.squares) |*square| {
            const next = [2]i32{ square[0], square[1] + 1 };
            if (self.touch_other_square(next)) {
                return false;
            }
        }
        return true;
    }

    fn active_piece_can_go_left(self: *Game) bool {
        const active_left = self.active_piece.left_square();
        if (active_left == 0) {
            return false;
        }

        // Check if the piece is touching other squares
        for (&self.active_piece.squares) |*square| {
            const next = [2]i32{ square[0], square[1] - 1 };
            if (self.touch_other_square(next)) {
                return false;
            }
        }
        return true;
    }

    /// Drop the active piece down by 1 slot, if it touches other squares or reaches the end of the board,
    /// return an error
    pub fn gravity_active_piece(self: *Game) error{Touched}!void {
        // Check if the piece is touching other squares
        for (&self.active_piece.squares) |*square| {
            const next = [2]i32{ square[0] + 1, square[1] };
            if (next[0] == TOTAL_ROWS) {
                return error.Touched;
            }

            if (self.touch_other_square(next)) {
                return error.Touched;
            }
        }

        for (&self.active_piece.squares) |*square| {
            square[0] += 1;
        }
    }

    /// Release the active piece, make it part of the board, set the active piece to the next piece and
    /// spawn a new next piece
    pub fn release_active_piece(self: *Game) void {
        for (self.active_piece.squares) |square| {
            self.board[@intCast(square[0])][@intCast(square[1])] = .{
                .active = true,
                .type = self.active_piece.kind,
            };
        }

        self.active_piece = self.next_piece;
        self.next_piece = Game.spawn_piece();
    }

    /// Move piece to the left or right based on the direction
    pub fn move_active_piece(self: *Game, direction: Direction) void {
        switch (direction) {
            .Left => {
                if (self.active_piece_can_go_left() == true) {
                    for (&self.active_piece.squares) |*square| {
                        square[1] -= 1;
                    }
                }
            },
            .Right => {
                if (self.active_piece_can_go_right() == true) {
                    for (&self.active_piece.squares) |*square| {
                        square[1] += 1;
                    }
                }
            },
        }
    }

    /// Rotate the active piece clockwise or counterclockwise based on the direction
    pub fn rotate_active_piece(self: *Game, direction: Direction) void {
        switch (direction) {
            .Left => {
                self.active_piece.rotate(-1.0, self.*);
            },
            .Right => {
                self.active_piece.rotate(1.0, self.*);
            },
        }
    }

    pub fn delete_full_rows_if_exists(self: *Game) void {
        var deleted_rows: u32 = 0;

        for (self.board, 0..) |rows, row| {
            var full_row = true;

            // Check if the row is full
            for (rows) |square| {
                if (square.active == false) {
                    full_row = false;
                    break;
                }
            }

            // Delete the row
            if (full_row == true) {
                deleted_rows += 1;

                var row_start = row;
                while (row_start > 0) {
                    for (self.board[row_start], 0..) |_, col| {
                        self.board[row_start][col] = self.board[row_start - 1][col];
                    }
                    row_start -= 1;
                }
            }
        }

        self.destroyed_lines += deleted_rows;
    }

    pub fn check_game_over(self: Game) bool {
        for (self.board[0]) |slot| {
            if (slot.active == true) {
                return true;
            }
        }

        return false;
    }

    pub fn draw_on_window(self: Game, starting_x: usize) void {
        const ToDraw = struct {
            rect: rl.Rectangle,
            color: rl.Color,
        };
        var to_draw: [TOTAL_ROWS][COLS]ToDraw = undefined;

        for (self.board, 0..) |rows, row| {
            if (row < HIDDEN_ROWS) {
                continue;
            }
            for (rows, 0..) |square, col| {
                if (square.active == true) {
                    to_draw[row][col] = .{
                        .rect = .{
                            .x = @floatFromInt(col * SQUARE_SIZE + starting_x),
                            .y = @floatFromInt(row * SQUARE_SIZE - HIDDEN_ROWS * SQUARE_SIZE),
                            .width = @floatFromInt(SQUARE_SIZE),
                            .height = @floatFromInt(SQUARE_SIZE),
                        },
                        .color = square.type.?.color(),
                    };
                }
            }
        }

        for (to_draw) |row| {
            for (row) |square| {
                rl.drawRectangleRec(square.rect, square.color);
                rl.drawRectangleLinesEx(square.rect, 2.0, rl.Color.black);
            }
        }

        for (self.active_piece.squares) |square| {
            const rect: rl.Rectangle = .{
                .x = @floatFromInt(@as(usize, @intCast(square[1] * SQUARE_SIZE)) + starting_x),
                .y = @floatFromInt(square[0] * SQUARE_SIZE - HIDDEN_ROWS * SQUARE_SIZE),
                .width = @floatFromInt(SQUARE_SIZE),
                .height = @floatFromInt(SQUARE_SIZE),
            };
            rl.drawRectangleRec(
                rect,
                self.active_piece.kind.color(),
            );
            rl.drawRectangleLinesEx(rect, 2.0, rl.Color.black);
        }
    }

    pub fn print(self: Game) void {
        for (self.board, 0..) |rows, row| {
            for (rows, 0..) |square, col| {
                if (square.active == false) {
                    var square_printed = false;
                    for (self.active_piece.squares) |piece_square| {
                        if (piece_square[0] == row and piece_square[1] == col) {
                            std.debug.print("X", .{});
                            square_printed = true;
                        }
                    }
                    if (square_printed == false) {
                        std.debug.print(" ", .{});
                    }
                } else {
                    std.debug.print("X", .{});
                }
            }
            std.debug.print("\n", .{});
        }
    }
};

fn clear_terminal() void {
    std.debug.print("\x1B[2J\x1B[H", .{});
}

pub fn main() !void {
    rand_prng = std.Random.DefaultPrng.init(curr_time());
    rand_gen = rand_prng.random();
    const screenWidth = COLS * SQUARE_SIZE + GUI_SIZE;
    const screenHeight = ROWS * SQUARE_SIZE;
    const level = 9;
    const level_delta = (10 - level) * 10;

    rl.initWindow(screenWidth, screenHeight, "Tetrig");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var game = Game.init();

    var gravity_wait: u32 = level_delta;
    while (!rl.windowShouldClose()) {
        gravity_wait -= 1;

        // Key Handling
        if (rl.isKeyPressed(rl.KeyboardKey.key_right)) game.move_active_piece(Direction.Right);
        if (rl.isKeyPressed(rl.KeyboardKey.key_left)) game.move_active_piece(Direction.Left);
        if (rl.isKeyPressed(rl.KeyboardKey.key_z)) game.rotate_active_piece(Direction.Left);
        if (rl.isKeyPressed(rl.KeyboardKey.key_x)) game.rotate_active_piece(Direction.Right);
        if (rl.isKeyDown(rl.KeyboardKey.key_down)) {
            if (gravity_wait > 1) {
                gravity_wait -= 2;
            }
        }

        if (gravity_wait == 0) {
            gravity_wait = level_delta;
            game.gravity_active_piece() catch {
                game.release_active_piece();
                game.delete_full_rows_if_exists();
                const game_over = game.check_game_over();

                if (game_over == true) {
                    break;
                }
            };
        }

        // game.print();
        // std.time.sleep(300_000_000); // 1_000_000_000
        // clear_terminal();
        rl.beginDrawing();
        rl.clearBackground(rl.Color.ray_white);
        game.draw_on_window(GUI_SIZE);
        rl.endDrawing();
    }
}
