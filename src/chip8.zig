const std = @import("std");
const fs = std.fs;
const constants = @import("constants.zig");

const debugops = @import("build_options").debugops;

const uptr = u16;

const MEM_SIZE = constants.MEM_SIZE;
const PROGRAM_START = constants.PROGRAM_START;
const FONTSET_START = constants.FONTSET_START;
const FONTSET_SIZE = constants.FONTSET_SIZE;
const VIDEO_WIDTH = constants.VIDEO_WIDTH;
const VIDEO_HEIGHT = constants.VIDEO_HEIGHT;
const DISPLAY_MEM_SIZE = constants.DISPLAY_MEM_SIZE;
const SPRITE_WIDTH = constants.SPRITE_WIDTH;
const KEY_COUNT = constants.KEY_COUNT;

/// spec: https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&cad=rja&uact=8&ved=2ahUKEwig2tfivtyAAxWB2AIHHfhiC1AQFnoECBkQAw&url=http%3A%2F%2Fwww.cs.columbia.edu%2F~sedwards%2Fclasses%2F2016%2F4840-spring%2Fdesigns%2FChip8.pdf&usg=AOvVaw0xHA18fGOVun0XbjJEP6ia&opi=89978449
pub fn CHIP8(comptime DisplayBufferType: type, comptime on: DisplayBufferType, comptime off: DisplayBufferType) type {
    return struct {
        /// address space from 0x000 to 0xFFF
        /// 0x000-0x1FF: reserved for CHIP-8 interpreter
        /// 0x050-0x0A0: storage space for font
        /// 0x200-0xFFF: instructions from the ROM
        memory: [MEM_SIZE]u8,
        /// 16 8-bit registers labeled V0 to VF
        registers: [16]u8,
        /// Special register used to store memory addresses for us in operations
        indexRegister: u16,
        pc: u16,
        /// Stack can hold 16 program counters
        stack: [16]u16,
        /// Stack pointer
        sp: u8,
        /// decrements at a rate of 60Hz, until it reaches zero
        delayTimer: u8,
        // decrements at a rate of 60Hz, until it reaches zero, playing a buzz when non-zero
        soundTimer: u8,
        // 16 input keys 0 through F
        keypad: [KEY_COUNT]bool,
        displayMemory: [DISPLAY_MEM_SIZE]DisplayBufferType,

        // Emulater specific
        rng: std.rand.DefaultPrng,
        opcode: u16,

        const Self = @This();

        pub fn init() Self {
            std.debug.print("{}\n", .{@sizeOf(DisplayBufferType)});
            // zig fmt: off
            var chip8 = Self{
                .memory = undefined,
                .registers = std.mem.zeroes([16]u8),
                .indexRegister = 0,
                .pc = PROGRAM_START,
                // .pc = 0x600,
                .stack = undefined,
                .sp = 0,
                .delayTimer = 0,
                .soundTimer = 0,
                .keypad = std.mem.zeroes([16]bool),
                .displayMemory = std.mem.zeroes([DISPLAY_MEM_SIZE]DisplayBufferType),

                .rng = std.rand.DefaultPrng.init(@bitCast(u64, std.time.timestamp())),
                .opcode = 0,
            };

            // (@ptrCast([*]u8, chip8.memory) + @intCast(usize, FONTSET_START)) = .{
            var memSlice: []u8 = chip8.memory[FONTSET_START..FONTSET_START+FONTSET_SIZE];
        
            // (&chip8.memory[0..].ptr + @intCast(usize, FONTSET_START)) = .{
            comptime var i = 0;
            const font: [FONTSET_SIZE]u8 = .{
                0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
                0x20, 0x60, 0x20, 0x20, 0x70, // 1
                0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
                0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
                0x90, 0x90, 0xF0, 0x10, 0x10, // 4
                0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
                0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
                0xF0, 0x10, 0x20, 0x40, 0x40, // 7
                0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
                0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
                0xF0, 0x90, 0xF0, 0x90, 0x90, // A
                0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
                0xF0, 0x80, 0x80, 0x80, 0xF0, // C
                0xE0, 0x90, 0x90, 0x90, 0xE0, // D
                0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
                0xF0, 0x80, 0xF0, 0x80, 0x80  // F
            };
            inline while (i < FONTSET_START) : (i += 1) {
                memSlice[i] = font[i];
            }
        
            return chip8;
        }
        pub fn loadROM(self: *Self, dir: fs.Dir, filename: []const u8) !void {
            var file: fs.File = try dir.openFile(filename, .{.mode = .read_only});
            defer file.close();

            var bufReader = std.io.bufferedReader(file.reader());
            var inStream = bufReader.reader();
            var programMemSlice: []u8 = self.memory[PROGRAM_START..MEM_SIZE];
        
            _ = try inStream.readAll(programMemSlice);

            self.pc = PROGRAM_START;
        }

        fn rand(self: *Self) u8 {
            return self.rng.random().int(u8);
        }

        // CLS:
        fn op_00E0(self: *Self) void {
            if (debugops) std.debug.print("CLS\n", .{});
            // const dmem: []u1 = self.displayMemory[0..DISPLAY_MEM_SIZE];
            // @memset(@ptrCast([*]u8, dmem.ptr), 0, DISPLAY_MEM_SIZE / 8);
            var i: u32 = 0;
            while (i < DISPLAY_MEM_SIZE) : (i += 1) {
                self.displayMemory[i] = 0;
            }
        }
    
        // RET: 
        fn op_00EE(self: *Self) void {
            if (debugops) std.debug.print("RET\n", .{});
            self.sp -= 1;
            self.pc = self.stack[self.sp];
        }

        // JMP: jump to address nnn
        fn op_1nnn(self: *Self) void {
            if (debugops) std.debug.print("Jump to address 0x{x}\n", .{self.nnn()});
            self.pc = self.nnn();
        }

        // CALL: call the subroutine at nnn
        fn op_2nnn(self: *Self) void {
            if (debugops) std.debug.print("CALL nnn: address = {}\n", .{self.nnn()});
            // Put current pc on the stack
            self.stack[self.sp] = self.pc;
            self.sp += 1;

            // Move to instruction
            self.pc = self.nnn();
        }

        // SE: skip next instruction if Vx = kk
        fn op_3xkk(self: *Self) void {
            if (debugops) std.debug.print("SE x, kk: Vx = {}, kk = {}\n", .{self.registers[self.Vxus()], self.kk()});
            if (self.registers[self.Vxus()] == self.kk()) {
                self.pc += 2;
            }
        }

        // SNE: skip next instruction if Vx != kk
        fn op_4xkk(self: *Self) void {
            if (debugops) std.debug.print("SNE x, kk: Vx = {}, kk = {}\n", .{self.registers[self.Vxus()], self.kk()});
            if (self.registers[self.Vxus()] != self.kk()) {
                self.pc += 2;
            }
        }

        // SE: 5xy0
        fn op_5xy0(self: *Self) void {
            if (debugops) std.debug.print("SE x, y: Vx = {}, Vy = {}\n", .{self.registers[self.Vxus()], self.registers[self.Vyus()]});
            if (self.registers[self.Vxus()] == self.registers[self.Vyus()]) {
                self.pc += 2;
            }
        }

        // LD: 6xkk: set Vx = kk
        fn op_6xkk(self: *Self) void {
            if (debugops) std.debug.print("Set V[0x{x}] to 0x{x}\n", .{self.Vxus(), self.kk()});
            self.registers[self.Vxus()] = self.kk();
        }

        // ADD: 7xkk: set Vx = Vx + kk
        fn op_7xkk(self: *Self) void {
            if (debugops) std.debug.print("ADD x, kk: Vx = {}, kk = {}\n", .{self.registers[self.Vxus()], self.kk()});
            self.registers[self.Vxus()] +%= self.kk();
        }

        // LD: 8xy0: Vx = Vy
        fn op_8xy0(self: *Self) void {
            if (debugops) std.debug.print("LD x, y: Vx = {}, Vy = {}\n", .{self.registers[self.Vxus()], self.registers[self.Vyus()]});
            self.registers[self.Vxus()] = self.registers[self.Vyus()];
        }

        // OR: 8xy1
        fn op_8xy1(self: *Self) void {
            if (debugops) std.debug.print("OR x, y: Vx = {}, Vy = {}\n", .{self.registers[self.Vxus()], self.registers[self.Vyus()]});
            self.registers[self.Vxus()] |= self.registers[self.Vyus()];
        }

        // AND: 8xy2
        fn op_8xy2(self: *Self) void {
            if (debugops) std.debug.print("AND x, y\n", .{});
            self.registers[self.Vxus()] &= self.registers[self.Vyus()];
        }

        // XOR: 8xy3
        fn op_8xy3(self: *Self) void {
            if (debugops) std.debug.print("XOR x, y\n", .{});
            self.registers[self.Vxus()] ^= self.registers[self.Vyus()];
        }

        // ADD: 8xy4: Vx and Vy added together, if the result overflows, Vf is set to 1,
        // otherwise it is set to 0
        fn op_8xy4(self: *Self) void {
            if (debugops) std.debug.print("ADD x, y\n", .{});
            var sum: u16 = @intCast(u16, self.registers[self.Vxus()]) + @intCast(u16, self.registers[self.Vyus()]);

            if (sum > 255) {
                self.registers[0xF] = 1;
            } else {
                self.registers[0xF] = 0;
            }

            // TODO: in if sum > 255 -> sum = sum % 255; (or sum - 255)
            //self.registers[self.Vxus()] = @intCast(u8, sum & 0xFF); //& 0xFF;
            self.registers[self.Vxus()] +%= self.registers[self.Vyus()];
        }

        // SUB: 8xy5
        fn op_8xy5(self: *Self) void {
            if (debugops) std.debug.print("SUB x, y\n", .{});
            const _Vx = self.Vx();
            const _Vy = self.Vy();

            if (self.registers[_Vx] > self.registers[_Vy]) {
                self.registers[0xF] = 1;
            } else {
                self.registers[0xF] = 0;
            }

            self.registers[_Vx] = self.registers[_Vx] -% self.registers[_Vy];
        }

        // SHR: 8xy6
        // shift right (= divide by two) Vx. lsb stored in Vf
        fn op_8xy6(self: *Self) void {
            if (debugops) std.debug.print("shr x, y\n", .{});
            self.registers[0xF] = (self.registers[self.Vxus()] & 0x1);

            self.registers[self.Vxus()] >>= 1; // /= 2
            // TODO?: @shlWithOverflow(u8, self.registers[self.Vxus()], 1, &self.registers[self.Vxus()]);
        }

        // SUBN: 8xy7
        fn op_8xy7(self: *Self) void {
            if (debugops) std.debug.print("SUBN x, y\n", .{});
            if (self.registers[self.Vyus()] > self.registers[self.Vxus()]) {
                self.registers[0xF] = 1;
            } else {
                self.registers[0xF] = 0;
            }

            self.registers[self.Vxus()] = self.registers[self.Vyus()] -% self.registers[self.Vxus()];
        }

        // SHL: 8xyE
        fn op_8xyE(self: *Self) void {
            if (debugops) std.debug.print("SHL x, y\n", .{});
            // Most significant bit into reg Vf
            self.registers[0xF] = (self.registers[self.Vxus()] & 0x80) >> 7;

            self.registers[self.Vxus()] <<= 1; // TODO: does overflow?
        }

        // SNE: 9xy0: skip
        fn op_9xy0(self: *Self) void {
            if (debugops) std.debug.print("SNE x, y\n", .{});
            if (self.registers[self.Vxus()] != self.registers[self.Vyus()]) {
                self.pc += 2;
            }
        }

        // LD: Annn LD I, addr
        // set I = nnn
        fn op_Annn(self: *Self) void {
            if (debugops) std.debug.print("Set I to 0x{x}\n", .{self.nnn()});
            self.indexRegister = self.nnn();
        }

        /// JMP: jump to location nnn + V0
        fn op_Bnnn(self: *Self) void {
            if (debugops) std.debug.print("JP nnn: address = {}, jump location = {}\n", .{self.nnn(), self.nnn() + self.registers[0]});
            self.pc = self.registers[0] + self.nnn();
        }

        // RND: set Vx = random byte AND kk
        fn op_Cxkk(self: *Self) void {
            if (debugops) std.debug.print("RND: mask = {}\n", .{self.kk()});
            self.registers[self.Vxus()] = self.rand() & self.kk();
        }
    
        /// DRW: Vx, Vy, nibble
        /// Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision.
        fn op_Dxyn(self: *Self) void {
            const _x = self.Vx();
            const _y = self.Vy();
            const height = self.opcode & 0x000F; // amount of bytes to read

                                                 // wrap when going beyond screen boundary
            const xPos: u8 = self.registers[_x] % VIDEO_WIDTH;
            const yPos: u8 = self.registers[_y] % VIDEO_HEIGHT;

            if (debugops) std.debug.print("DRAW sprite at (V[0x{x}] % 64, V[0x{x}] % 32) = (0x{x}, 0x{x}) of height = {}\n", .{_x, _y, xPos, yPos, height});

            self.registers[0xF] = 0;

            // const firstByte: u8 = 0b10000000;
            // row = byte in the byte array we read (n bytes)
            var row: u8 = 0; // 0 to max 15
            // bit in the byte row
            var col: u4 = 0; // 0 to 8
            while (row < height) : (row += 1) {
                const spriteRow: u8 = self.memory[self.indexRegister + row];
                if (debugops) std.debug.print("> spriteRow = 0x{x}\n", .{spriteRow});
                const y: usize = (@intCast(usize, yPos) + @intCast(usize, row)) % VIDEO_HEIGHT;

                col = 0;
                while (col < SPRITE_WIDTH) : (col += 1) {
                    const x: usize = (@intCast(usize, xPos) + @intCast(usize, 7 - col)) % VIDEO_WIDTH;
                    // const screenPixel: *u1 = &self.displayMemory[y + x];
                    // const pixelMask = firstByte >> @intCast(u3, col);
                    // const spritePixel: u8 = spriteRow & pixelMask;
                    const spritePixel: u1 = @intCast(u1, (spriteRow >> @intCast(u3, col)) & 0x1);
                    const screenPixel: *DisplayBufferType = &self.displayMemory[y * VIDEO_WIDTH + x];
                
                    // Take each bit of the row = 1 pixel
                    // var spritePixel: u8 = spriteRow & (firstByte >> @intCast(u3, col));
                    // var screenPixel: *u1 = &self.displayMemory[@intCast(usize, yPos + row) * VIDEO_WIDTH + (xPos + col)];

                    // std.debug.print("set ({}, {}) = {}\n", .{row, col, spritePixel});

                    // if (spritePixel == 1 and screenPixel.* == 1) {
                    //     self.registers[0xF] = 1;
                    // }

                    // screenPixel.* = screenPixel.* ^ spritePixel;

                    if (spritePixel == 1) {
                        // Collision with screen pixel
                        if (screenPixel.* == on) {
                            // current pixel is on
                            screenPixel.* = off; // 1 ^ 1 == 0
                            // Pixel will be erased
                            self.registers[0xF] = 1;
                        } else {
                            // current pixel is off
                            screenPixel.* = on;
                        }
                    }

                    //     // XOR with screen pixel
                    // } // spritePixel is 0, so screenPixel stays the same

                    // std.debug.print("col = {} > {}\n", .{col, SPRITE_WIDTH});
                }
            }

            if (debugops) {
                std.debug.print("x = {}, y = {}\n", .{xPos, yPos});
            
                var __y: usize = 0;
                while (__y < height) : (__y += 1) {
                    var __x: usize = 0;
                    while (__x < 8) : (__x += 1) {
                        std.debug.print("{}", .{self.displayMemory[((yPos + __y) % VIDEO_HEIGHT) * VIDEO_WIDTH + (xPos + __x) % VIDEO_WIDTH]});
                    }
                    std.debug.print("\n", .{});
                }
            }
        }

        /// SKP: skip next instruction if key with the value of Vx is pressed
        fn op_Ex9E(self: *Self) void {
            if (debugops) std.debug.print("SKP x\n", .{});
            const key = self.registers[self.Vxus()];

            if (self.keypad[key]) {
                // PC has been incremented in cycle, so we can increment again to skip instruction
                self.pc += 2;
            }
        }

        // SKNP: skip if not equal
        fn op_ExA1(self: *Self) void {
            if (debugops) std.debug.print("SKNP\n", .{});
            const key = self.registers[self.Vxus()];

            if (!self.keypad[key]) {
                self.pc += 2;
            }
        }

        /// LD:
        fn op_Fx07(self: *Self) void {
            if (debugops) std.debug.print("LD x: delay timer = {}\n", .{self.delayTimer});
            self.registers[self.Vxus()] = self.delayTimer;
        }

        // LD: wait for a keypress and store the value in Vx
        fn op_Fx0A(self: *Self) void {
            if (debugops) std.debug.print("LD x: waiting for keypress\n", .{});
            const _Vx = self.Vx();
            comptime var i = 0;
            if (
                !(inline while (i < KEY_COUNT) : (i += 1) {
                    if (self.keypad[i]) {
                        self.registers[_Vx] = i;
                        break true;
                    }
                } else false)
            ) {
                self.pc -= 2;
            }
        }

        // LD:
        fn op_Fx15(self: *Self) void {
            if (debugops) std.debug.print("LD: into delay timer\n", .{});
            self.delayTimer = self.registers[self.Vxus()];
        }

        // LD:
        fn op_Fx18(self: *Self) void {
            if (debugops) std.debug.print("LD: into soundTimer\n", .{});
            self.soundTimer = self.registers[self.Vxus()];
        }

        /// ADD: Set I = I + Vx
        fn op_Fx1E(self: *Self) void {
            if (debugops) std.debug.print("ADD: I = I + Vx\n", .{});
            self.indexRegister += self.registers[self.Vxus()];
        }

        /// LD: Set I = location of sprite for digit Vx.
        fn op_Fx29(self: *Self) void {
            if (debugops) std.debug.print("LD: I = Vx\n", .{});
            const digit = self.registers[self.Vxus()];
        
            self.indexRegister = FONTSET_START + (5 * digit);
        }

        /// LD: Store BCD representation of Vx in memory locations I, I+1, and I+2.
        /// The interpreter takes the decimal value of Vx, and places the hundreds digit in
        /// memory at location in I, the tens digit at location I+1, and the ones digit at location I+2.
        fn op_Fx33(self: *Self) void {
            if (debugops) std.debug.print("LD: BCD rep\n", .{});
            var val = self.registers[self.Vxus()];

            self.memory[self.indexRegister + 2] = val % 10;
            val /= 10;

            self.memory[self.indexRegister + 1] = val % 10;
            val /= 10;

            self.memory[self.indexRegister] = val % 10;

        
            // self.memory[self.indexRegister] = (self.registers[self.Vxus()] % 1000) / 100; // hundred's digit
            // self.memory[self.indexRegister+1] = (self.registers[self.Vxus()] % 100) / 10; // ten's digit
            // self.memory[self.indexRegister+2] = (self.registers[self.Vxus()] % 10); // one's digit
        }

        /// LD: Store registers V0 through Vx in memory starting at location I
        fn op_Fx55(self: *Self) void {
            if (debugops) std.debug.print("LD\n", .{});
            const x = self.Vx();
        
            var i: uptr = 0;
            while (i < x) : (i += 1) {
                self.memory[self.indexRegister + i] = self.registers[i];
            }
            self.indexRegister += x + 1;
        }

        /// LD: Read registers V0 through Vx from memory starting at location I
        fn op_Fx65(self: *Self) void {
            if (debugops) std.debug.print("LD\n", .{});
            const x = self.Vx();

            var i: u8 = 0;
            while (i < x) : (i += 1) {
                self.registers[i] = self.memory[self.indexRegister + i];
            }
            self.indexRegister += x + 1;
        }

        fn execOp(self: *Self) void {
            // std.debug.print("0x{X} -> 0x{X}\n", self.opcode, self.opcode & 0xF000);
            switch (self.opcode & 0xF000) {
                // Unique opcodes
                0x1000 => self.op_1nnn(),
                0x2000 => self.op_2nnn(),
                0x3000 => self.op_3xkk(),
                0x4000 => self.op_4xkk(),
                0x5000 => self.op_5xy0(),
                0x6000 => self.op_6xkk(),
                0x7000 => self.op_7xkk(),
                0x9000 => self.op_9xy0(),
                0xA000 => self.op_Annn(),
                0xB000 => self.op_Bnnn(),
                0xC000 => self.op_Cxkk(),
                0xD000 => self.op_Dxyn(),

                // CODExyUnique
                0x8000 => {
                    switch (self.opcode & 0x000F) {
                        0x0000 => self.op_8xy0(),
                        0x0001 => self.op_8xy1(),
                        0x0002 => self.op_8xy2(),
                        0x0003 => self.op_8xy3(),
                        0x0004 => self.op_8xy4(),
                        0x0005 => self.op_8xy5(),
                        0x0006 => self.op_8xy6(),
                        0x0007 => self.op_8xy7(),
                        0x000E => self.op_8xyE(),
                        else => unreachable
                    }
                },

                // 00EUnique
                0x0000 => {
                    switch (self.opcode) {
                        0x00E0 => self.op_00E0(),
                        0x00EE => self.op_00EE(),
                        else => unreachable
                    }
                },

                // CODExUniqueUnique
                0xE000 => {
                    switch (self.opcode & 0x00FF) {
                        0x00A1 => self.op_ExA1(),
                        0x009E => self.op_Ex9E(),
                        else => unreachable
                    }
                },
                0xF000 => {
                    switch (self.opcode & 0x00FF) {
                        0x0007 => self.op_Fx07(),
                        0x000A => self.op_Fx0A(),
                        0x0015 => self.op_Fx15(),
                        0x0018 => self.op_Fx18(),
                        0x001E => self.op_Fx1E(),
                        0x0029 => self.op_Fx29(),
                        0x0033 => self.op_Fx33(),
                        0x0055 => self.op_Fx55(),
                        0x0065 => self.op_Fx65(),
                        else => unreachable
                    }
                },

                else => unreachable
            }
        }

        pub fn cycle(self: *Self) void {
            self.opcode = (@intCast(u16, self.memory[self.pc]) << 8) | (self.memory[self.pc + 1]);
            if (debugops) std.debug.print("PC: 0x{x} Op: 0x{x}\n", .{self.pc, self.opcode});
            // std.debug.print("0x{X}\n", .{self.opcode});
            self.pc += 2;

            self.execOp();

            // debug state
            if (debugops) {
                std.debug.print("------------------------------------------------------------------\n", .{});
                std.debug.print("\n", .{});
                std.debug.print("V0: 0x{x}  V4: 0x{x}  V8: 0x{x}  VC: 0x{x}\n", .{self.registers[0], self.registers[4], self.registers[8], self.registers[0xC]});
                std.debug.print("V1: 0x{x}  V5: 0x{x}  V9: 0x{x}  VD: 0x{x}\n", .{self.registers[1], self.registers[5], self.registers[9], self.registers[0xD]});
                std.debug.print("V2: 0x{x}  V6: 0x{x}  VA: 0x{x}  VE: 0x{x}\n", .{self.registers[2], self.registers[6], self.registers[0xA], self.registers[0xE]});
                std.debug.print("V3: 0x{x}  V7: 0x{x}  VB: 0x{x}  VF: 0x{x}\n", .{self.registers[3], self.registers[7], self.registers[0xB], self.registers[0xF]});
                std.debug.print("\n", .{});
                std.debug.print("PC: 0x{x}\n", .{self.pc});
                std.debug.print("\n\n", .{});
            }

            // zig fmt: off
            if (self.delayTimer > 0) { self.delayTimer -= 1; }
            if (self.soundTimer > 0) { self.soundTimer -= 1; }
        }

        fn Vx(self: *Self) u8 {
            return @intCast(u8, (self.opcode & 0x0F00) >> 8);
        }
        inline fn Vxus(self: *Self) usize {
            return self.Vx();
        }
        fn Vy(self: *Self) u8 {
            return @intCast(u8, (self.opcode & 0x00F0) >> 4);
        }
        inline fn Vyus(self: *Self) usize {
            return self.Vy();
        }
        fn kk(self: *Self) u8 {
            return @intCast(u8, self.opcode & 0x00FF);
        }
        fn nnn(self: *Self) u16 {
            return self.opcode & 0x0FFF;
        }
    };
}
