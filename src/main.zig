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
const LINE_THICKNESS = 2.0;

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
    score: u32,

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
            .score = 0,
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

    fn update_score(self: *Game, lines: u32, level: u32) void {
        const score = switch (lines) {
            1 => 40 * (level + 1),
            2 => 100 * (level + 1),
            3 => 300 * (level + 1),
            4 => 1200 * (level + 1),
            else => 0,
        };
        self.score += score;
    }

    pub fn delete_full_rows_if_exists(self: *Game) u32 {
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
        return deleted_rows;
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
        for (self.board, 0..) |rows, row| {
            if (row < HIDDEN_ROWS) {
                continue;
            }
            for (rows, 0..) |square, col| {
                if (square.active == true) {
                    const to_draw: rl.Rectangle = .{
                        .x = @floatFromInt(col * SQUARE_SIZE + starting_x),
                        .y = @floatFromInt(row * SQUARE_SIZE - HIDDEN_ROWS * SQUARE_SIZE), // - HIDDEN_ROWS * SQUARE_SIZE),
                        .width = @floatFromInt(SQUARE_SIZE),
                        .height = @floatFromInt(SQUARE_SIZE),
                    };
                    rl.drawRectangleRec(to_draw, square.type.?.color());
                    rl.drawRectangleLinesEx(to_draw, LINE_THICKNESS, rl.Color.black);
                }
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
            rl.drawRectangleLinesEx(rect, LINE_THICKNESS, rl.Color.black);
        }
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

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
                const deleted_rows = game.delete_full_rows_if_exists();
                game.update_score(deleted_rows, level);
                const game_over = game.check_game_over();

                if (game_over == true) {
                    break;
                }
            };
        }

        rl.beginDrawing();
        rl.clearBackground(rl.Color.ray_white);

        // Game Drawing
        game.draw_on_window(GUI_SIZE);

        // GUI Drawing
        {
            rl.drawRectangleLinesEx(rl.Rectangle.init(0, 0, GUI_SIZE, screenHeight), 15, rl.Color.light_gray);

            // Score text and value
            rl.drawText("Score:", 25, 50, 25, rl.Color.dark_gray);
            var score_buf: [50]u8 = undefined;
            const score_as_str = try std.fmt.bufPrint(&score_buf, "{}", .{game.score});
            const score_as_str_z = try allocator.dupeZ(u8, score_as_str);
            rl.drawText(score_as_str_z, 115, 51, 25, rl.Color.sky_blue);

            // Deleted Lines text and value
            rl.drawText("Del. Lines:", 25, 100, 25, rl.Color.dark_gray);
            var del_buf: [50]u8 = undefined;
            const del_as_str = try std.fmt.bufPrint(&del_buf, "{}", .{game.destroyed_lines});
            const del_as_str_z = try allocator.dupeZ(u8, del_as_str);
            rl.drawText(del_as_str_z, 155, 101, 25, rl.Color.sky_blue);

            // Next Piece text and new piece
            rl.drawText("Next Piece", 85, 420, 25, rl.Color.dark_gray);
            const next_piece_color = game.next_piece.kind.color();
            for (game.next_piece.squares) |square| {
                var new_x: f32 = 0.0;
                if (game.next_piece.kind == PieceKind.I) {
                    new_x = @floatFromInt(square[1] * SQUARE_SIZE - 85);
                } else if (game.next_piece.kind == PieceKind.O) {
                    new_x = @floatFromInt(square[1] * SQUARE_SIZE - 50);
                } else {
                    new_x = @floatFromInt(square[1] * SQUARE_SIZE - 70);
                }
                const rect: rl.Rectangle = .{
                    .x = new_x,
                    .y = @floatFromInt(square[0] * SQUARE_SIZE + 510),
                    .width = @floatFromInt(SQUARE_SIZE),
                    .height = @floatFromInt(SQUARE_SIZE),
                };
                rl.drawRectangleRec(rect, next_piece_color);
                rl.drawRectangleLinesEx(rect, LINE_THICKNESS, rl.Color.black);
            }
        }

        rl.endDrawing();
    }
}
