const std = @import("std");
const rl = @import("raylib");

// Random Generator
const SEED = 42;
var rand_prng = std.Random.DefaultPrng.init(SEED);
const rand_gen = rand_prng.random();

// Constants
const COLS = 10;
const ROWS = 20;
const HIDDEN_ROWS = 2;
const TOTAL_ROWS = ROWS + HIDDEN_ROWS;

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

    pub fn left_square(self: Piece) i32 {
        var min_col: i32 = 100;
        for (self.squares) |square| {
            if (square[1] < min_col) {
                min_col = square[1];
            }
        }
        return min_col;
    }

    pub fn right_square(self: Piece) i32 {
        var max_col: i32 = 0;
        for (self.squares) |square| {
            if (square[1] > max_col) {
                max_col = square[1];
            }
        }
        return max_col;
    }

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

const Slot = struct {
    active: bool,
    type: PieceKind,
};

const Board = [TOTAL_ROWS][COLS]bool;

const Game = struct {
    board: Board,
    active_piece: Piece,
    next_piece: Piece,

    pub fn init() Game {
        var board: Board = undefined;
        for (board, 0..) |rows, row| {
            for (rows, 0..) |_, col| {
                if (row == TOTAL_ROWS - 1) {
                    board[row][col] = true;
                } else {
                    board[row][col] = false;
                }
            }
        }
        return Game{
            .board = board,
            .active_piece = Game.spawn_piece(),
            .next_piece = Game.spawn_piece(),
        };
    }

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

    fn touch_other_square(self: Game, square: Square) bool {
        if (self.board[@intCast(square[0])][@intCast(square[1])] == true) {
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

    pub fn gravity_active_piece(self: *Game) error{Touched}!void {
        // Check if the piece is touching other squares
        for (&self.active_piece.squares) |*square| {
            const next = [2]i32{ square[0] + 1, square[1] };
            if (next[0] == -1 or self.touch_other_square(next)) return error.Touched;
        }

        for (&self.active_piece.squares) |*square| {
            square[0] += 1;
        }
    }

    pub fn release_active_piece(self: *Game) void {
        for (self.active_piece.squares) |square| {
            self.board[@intCast(square[0])][@intCast(square[1])] = true;
        }

        self.active_piece = self.next_piece;
        self.next_piece = Game.spawn_piece();
    }

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

    pub fn draw_on_window(self: Game) void {
        _ = self; // autofix
    }

    pub fn print(self: Game) void {
        for (self.board, 0..) |rows, row| {
            for (rows, 0..) |square, col| {
                if (square == false) {
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
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "Tetrig");
    defer rl.closeWindow();
    rl.setTargetFPS(30);

    var game = Game.init();

    while (!rl.windowShouldClose()) {
        clear_terminal();

        // Key Handling
        if (rl.isKeyDown(rl.KeyboardKey.key_right)) game.move_active_piece(Direction.Right);
        if (rl.isKeyDown(rl.KeyboardKey.key_left)) game.move_active_piece(Direction.Left);
        if (rl.isKeyDown(rl.KeyboardKey.key_z)) game.rotate_active_piece(Direction.Left);
        if (rl.isKeyDown(rl.KeyboardKey.key_x)) game.rotate_active_piece(Direction.Right);

        // Draw
        game.print();
        std.time.sleep(300_000_000); // 1_000_000_000
        game.gravity_active_piece() catch {
            game.release_active_piece();
        };

        rl.beginDrawing();
        rl.clearBackground(rl.Color.ray_white);
        rl.endDrawing();
    }
}
