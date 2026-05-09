import chip8
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleeunit
import iv

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn new_system_test() {
  let assert Ok(system) = chip8.new_system([0x12, 0x34])

  assert system.pc == 512
  assert system.index_register == 0
  assert system.stack == []
  assert dict.size(system.registers) == 16
  assert dict.values(system.registers) |> list.all(fn(v) { v == 0 })

  let assert Ok(first_pixel) = iv.get(system.screen, 0)
  assert first_pixel == False
  let assert Ok(last_pixel) = iv.get(system.screen, 2047)
  assert last_pixel == False

  // Font is loaded at memory location 80; first byte of '0' glyph is 0xF0
  let assert Ok(font_byte) = iv.get(system.memory, 80)
  assert font_byte == 0xF0

  // ROM is loaded at memory location 512
  let assert Ok(rom_byte_0) = iv.get(system.memory, 512)
  assert rom_byte_0 == 0x12
  let assert Ok(rom_byte_1) = iv.get(system.memory, 513)
  assert rom_byte_1 == 0x34
}

pub fn clear_test() {
  // Draw the '0' font glyph at (0, 0), then clear the screen.
  let assert Ok(system) =
    chip8.new_system([
      0xA0, 0x50, 0x60, 0x00, 0x61, 0x00, 0xD0, 0x15, 0x00, 0xE0,
    ])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  let assert Ok(p_top_left) = iv.get(system.screen, 0)
  let assert Ok(p_next) = iv.get(system.screen, 1)
  let assert Ok(p_row_two) = iv.get(system.screen, 64)
  assert p_top_left == False
  assert p_next == False
  assert p_row_two == False

  assert system.pc == 522
}

pub fn jump_test() {
  let assert Ok(system) = chip8.new_system([0x1A, 0xBC])
  let assert Ok(system) = chip8.run(system)
  assert system.pc == 0xABC
}

pub fn set_test() {
  let assert Ok(system) = chip8.new_system([0x60, 0xFF, 0x6A, 0x12])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  let assert Ok(v0) = dict.get(system.registers, 0)
  let assert Ok(va) = dict.get(system.registers, 0xA)
  assert v0 == 0xFF
  assert va == 0x12
  assert system.pc == 516
}

pub fn add_test() {
  let assert Ok(system) = chip8.new_system([0x60, 0x05, 0x70, 0x03])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  let assert Ok(v0) = dict.get(system.registers, 0)
  assert v0 == 8
}

pub fn add_wraps_modulo_256_test() {
  // V0 = 0xFF, then add 1 — canonical CHIP-8 wraps to 0 and leaves VF untouched.
  let assert Ok(system) = chip8.new_system([0x60, 0xFF, 0x70, 0x01])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  let assert Ok(v0) = dict.get(system.registers, 0)
  let assert Ok(vf) = dict.get(system.registers, 15)
  assert v0 == 0
  assert vf == 0
}

pub fn set_idx_test() {
  let assert Ok(system) = chip8.new_system([0xA1, 0x23])
  let assert Ok(system) = chip8.run(system)
  assert system.index_register == 0x123
}

pub fn skip_val_eq_taken_test() {
  let assert Ok(system) = chip8.new_system([0x60, 0x05, 0x30, 0x05])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  assert system.pc == 518
}

pub fn skip_val_eq_not_taken_test() {
  let assert Ok(system) = chip8.new_system([0x60, 0x05, 0x30, 0x06])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  assert system.pc == 516
}

pub fn skip_val_neq_taken_test() {
  let assert Ok(system) = chip8.new_system([0x60, 0x05, 0x40, 0x06])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  assert system.pc == 518
}

pub fn skip_val_neq_not_taken_test() {
  let assert Ok(system) = chip8.new_system([0x60, 0x05, 0x40, 0x05])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  assert system.pc == 516
}

pub fn skip_reg_eq_taken_test() {
  let assert Ok(system) = chip8.new_system([0x60, 0x07, 0x61, 0x07, 0x50, 0x10])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  assert system.pc == 520
}

pub fn skip_reg_eq_not_taken_test() {
  let assert Ok(system) = chip8.new_system([0x60, 0x07, 0x61, 0x08, 0x50, 0x10])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  assert system.pc == 518
}

pub fn skip_reg_neq_taken_test() {
  let assert Ok(system) = chip8.new_system([0x60, 0x07, 0x61, 0x08, 0x90, 0x10])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  assert system.pc == 520
}

pub fn skip_reg_neq_not_taken_test() {
  let assert Ok(system) = chip8.new_system([0x60, 0x07, 0x61, 0x07, 0x90, 0x10])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  assert system.pc == 518
}

pub fn display_draws_sprite_test() {
  // I = 80 (font '0'), V0 = 0, V1 = 0, draw a 5-row sprite at (0, 0).
  let assert Ok(system) =
    chip8.new_system([0xA0, 0x50, 0x60, 0x00, 0x61, 0x00, 0xD0, 0x15])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  // Top row of '0' glyph: 0xF0 = 11110000
  let assert Ok(p00) = iv.get(system.screen, 0)
  let assert Ok(p10) = iv.get(system.screen, 1)
  let assert Ok(p20) = iv.get(system.screen, 2)
  let assert Ok(p30) = iv.get(system.screen, 3)
  let assert Ok(p40) = iv.get(system.screen, 4)
  assert p00 == True
  assert p10 == True
  assert p20 == True
  assert p30 == True
  assert p40 == False

  // Second row of '0' glyph: 0x90 = 10010000 (y=1 → screen indices 64..)
  let assert Ok(p01) = iv.get(system.screen, 64)
  let assert Ok(p11) = iv.get(system.screen, 65)
  let assert Ok(p21) = iv.get(system.screen, 66)
  let assert Ok(p31) = iv.get(system.screen, 67)
  assert p01 == True
  assert p11 == False
  assert p21 == False
  assert p31 == True

  let assert Ok(vf) = dict.get(system.registers, 15)
  assert vf == 0
}

pub fn display_collision_test() {
  // XOR the same sprite twice; pixels return to False and VF is set.
  let assert Ok(system) =
    chip8.new_system([
      0xA0, 0x50, 0x60, 0x00, 0x61, 0x00, 0xD0, 0x15, 0xD0, 0x15,
    ])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  let assert Ok(p00) = iv.get(system.screen, 0)
  let assert Ok(p10) = iv.get(system.screen, 1)
  let assert Ok(p01) = iv.get(system.screen, 64)
  let assert Ok(p31) = iv.get(system.screen, 67)
  assert p00 == False
  assert p10 == False
  assert p01 == False
  assert p31 == False

  let assert Ok(vf) = dict.get(system.registers, 15)
  assert vf == 1
}

pub fn display_wraps_starting_position_test() {
  // V0 = 64 wraps to 0, V1 = 32 wraps to 0; sprite renders at (0, 0).
  let assert Ok(system) =
    chip8.new_system([0xA0, 0x50, 0x60, 0x40, 0x61, 0x20, 0xD0, 0x15])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  let assert Ok(p00) = iv.get(system.screen, 0)
  assert p00 == True
}

pub fn decode_unknown_opcode_test() {
  let assert Ok(system) = chip8.new_system([0xFF, 0xFF])
  assert chip8.run(system) == Error(chip8.DecodeError(<<0xFF, 0xFF>>))
}

pub fn call_test() {
  // 0x200: 2ABC (call 0xABC)
  let assert Ok(system) = chip8.new_system([0x2A, 0xBC])
  let assert Ok(system) = chip8.run(system)
  assert system.pc == 0xABC
  assert system.stack == [0x202]
}

pub fn return_test() {
  // 0x200: 2206 (call 0x206)
  // 0x206: 00EE (return)
  let assert Ok(system) =
    chip8.new_system([0x22, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0xEE])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  assert system.pc == 0x202
  assert system.stack == []
}

pub fn set_x_to_y_test() {
  // V1 = 0x42, then V0 = V1
  let assert Ok(system) = chip8.new_system([0x61, 0x42, 0x80, 0x10])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  let assert Ok(v1) = dict.get(system.registers, 1)
  assert v0 == 0x42
  assert v1 == 0x42
}

pub fn or_test() {
  // V0 = 0xAA, V1 = 0xF0, then V0 |= V1 → 0xFA
  let assert Ok(system) = chip8.new_system([0x60, 0xAA, 0x61, 0xF0, 0x80, 0x11])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  assert v0 == 0xFA
}

pub fn and_test() {
  // V0 = 0xAA, V1 = 0xF0, then V0 &= V1 → 0xA0
  let assert Ok(system) = chip8.new_system([0x60, 0xAA, 0x61, 0xF0, 0x80, 0x12])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  assert v0 == 0xA0
}

pub fn xor_test() {
  // V0 = 0xAA, V1 = 0xF0, then V0 ^= V1 → 0x5A
  let assert Ok(system) = chip8.new_system([0x60, 0xAA, 0x61, 0xF0, 0x80, 0x13])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  assert v0 == 0x5A
}

pub fn add_y_to_x_test() {
  // V0 = 5, V1 = 3, then V0 += V1 → 8, VF = 0
  let assert Ok(system) = chip8.new_system([0x60, 0x05, 0x61, 0x03, 0x80, 0x14])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  let assert Ok(vf) = dict.get(system.registers, 15)
  assert v0 == 8
  assert vf == 0
}

pub fn add_y_to_x_overflow_test() {
  // V0 = 0xFF, V1 = 1, then V0 += V1 → 0, VF = 1 (8XY4 sets VF, unlike 7XNN)
  let assert Ok(system) = chip8.new_system([0x60, 0xFF, 0x61, 0x01, 0x80, 0x14])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  let assert Ok(vf) = dict.get(system.registers, 15)
  assert v0 == 0
  assert vf == 1
}

pub fn sub_y_from_x_test() {
  // V0 = 5, V1 = 3, then V0 -= V1 → 2, VF = 1 (no borrow)
  let assert Ok(system) = chip8.new_system([0x60, 0x05, 0x61, 0x03, 0x80, 0x15])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  let assert Ok(vf) = dict.get(system.registers, 15)
  assert v0 == 2
  assert vf == 1
}

pub fn sub_y_from_x_underflow_test() {
  // V0 = 3, V1 = 5, then V0 -= V1 → 254, VF = 0 (borrow)
  let assert Ok(system) = chip8.new_system([0x60, 0x03, 0x61, 0x05, 0x80, 0x15])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  let assert Ok(vf) = dict.get(system.registers, 15)
  assert v0 == 254
  assert vf == 0
}

pub fn sub_x_from_y_test() {
  // V0 = 3, V1 = 5, then V0 = V1 - V0 → 2, VF = 1 (no borrow)
  let assert Ok(system) = chip8.new_system([0x60, 0x03, 0x61, 0x05, 0x80, 0x17])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  let assert Ok(vf) = dict.get(system.registers, 15)
  assert v0 == 2
  assert vf == 1
}

pub fn sub_x_from_y_underflow_test() {
  // V0 = 5, V1 = 3, then V0 = V1 - V0 → 254, VF = 0 (borrow)
  let assert Ok(system) = chip8.new_system([0x60, 0x05, 0x61, 0x03, 0x80, 0x17])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  let assert Ok(vf) = dict.get(system.registers, 15)
  assert v0 == 254
  assert vf == 0
}

pub fn shift_right_test() {
  // V0 = 0xB4 (10110100), then V0 >>= 1 → 0x5A, VF = 0 (LSB was 0)
  let assert Ok(system) = chip8.new_system([0x60, 0xB4, 0x80, 0x06])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  let assert Ok(vf) = dict.get(system.registers, 15)
  assert v0 == 0x5A
  assert vf == 0
}

pub fn shift_right_lsb_set_test() {
  // V0 = 0xB5 (10110101), then V0 >>= 1 → 0x5A, VF = 1 (LSB was 1)
  let assert Ok(system) = chip8.new_system([0x60, 0xB5, 0x80, 0x06])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  let assert Ok(vf) = dict.get(system.registers, 15)
  assert v0 == 0x5A
  assert vf == 1
}

pub fn shift_left_test() {
  // V0 = 0x2D (00101101), then V0 <<= 1 → 0x5A, VF = 0 (MSB was 0)
  let assert Ok(system) = chip8.new_system([0x60, 0x2D, 0x80, 0x0E])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  let assert Ok(vf) = dict.get(system.registers, 15)
  assert v0 == 0x5A
  assert vf == 0
}

pub fn shift_left_msb_set_test() {
  // V0 = 0xAD (10101101), then V0 <<= 1 → 0x5A (truncated), VF = 1 (MSB was 1)
  let assert Ok(system) = chip8.new_system([0x60, 0xAD, 0x80, 0x0E])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  let assert Ok(vf) = dict.get(system.registers, 15)
  assert v0 == 0x5A
  assert vf == 1
}

pub fn store_test() {
  // V0..V3 = 0x11, 0x22, 0x33, 0x44; I = 0x300; FX55 with X=3 writes V0..V3
  // (inclusive) to memory[I..I+3].
  let assert Ok(system) =
    chip8.new_system([
      0x60, 0x11, 0x61, 0x22, 0x62, 0x33, 0x63, 0x44, 0xA3, 0x00, 0xF3, 0x55,
    ])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  let assert Ok(m0) = iv.get(system.memory, 0x300)
  let assert Ok(m1) = iv.get(system.memory, 0x301)
  let assert Ok(m2) = iv.get(system.memory, 0x302)
  let assert Ok(m3) = iv.get(system.memory, 0x303)
  assert m0 == 0x11
  assert m1 == 0x22
  assert m2 == 0x33
  assert m3 == 0x44

  // V4 is outside the range — its slot in memory must remain untouched.
  let assert Ok(m4) = iv.get(system.memory, 0x304)
  assert m4 == 0
}

pub fn load_test() {
  // I = 0x50 (font '0' glyph: F0 90 90 90 F0); FX65 with X=4 loads V0..V4
  // (inclusive) from memory[I..I+4].
  let assert Ok(system) = chip8.new_system([0xA0, 0x50, 0xF4, 0x65])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  let assert Ok(v0) = dict.get(system.registers, 0)
  let assert Ok(v1) = dict.get(system.registers, 1)
  let assert Ok(v2) = dict.get(system.registers, 2)
  let assert Ok(v3) = dict.get(system.registers, 3)
  let assert Ok(v4) = dict.get(system.registers, 4)
  assert v0 == 0xF0
  assert v1 == 0x90
  assert v2 == 0x90
  assert v3 == 0x90
  assert v4 == 0xF0

  // V5 is outside the range — must remain at its initial value of 0.
  let assert Ok(v5) = dict.get(system.registers, 5)
  assert v5 == 0
}

pub fn store_decimal_test() {
  // V0 = 156 (0x9C); I = 0x300; FX33 writes BCD digits to memory[I..I+2].
  let assert Ok(system) = chip8.new_system([0x60, 0x9C, 0xA3, 0x00, 0xF0, 0x33])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  let assert Ok(m0) = iv.get(system.memory, 0x300)
  let assert Ok(m1) = iv.get(system.memory, 0x301)
  let assert Ok(m2) = iv.get(system.memory, 0x302)
  assert m0 == 1
  assert m1 == 5
  assert m2 == 6
}

pub fn store_decimal_leading_zeros_test() {
  // V0 = 7; FX33 must still write three digits, padding with leading zeros.
  let assert Ok(system) = chip8.new_system([0x60, 0x07, 0xA3, 0x00, 0xF0, 0x33])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  let assert Ok(m0) = iv.get(system.memory, 0x300)
  let assert Ok(m1) = iv.get(system.memory, 0x301)
  let assert Ok(m2) = iv.get(system.memory, 0x302)
  assert m0 == 0
  assert m1 == 0
  assert m2 == 7
}

pub fn add_idx_test() {
  // I = 0x100, V0 = 0x05, then I += V0 → I = 0x105, VF = 0 (no overflow)
  let assert Ok(system) = chip8.new_system([0xA1, 0x00, 0x60, 0x05, 0xF0, 0x1E])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  let assert Ok(vf) = dict.get(system.registers, 15)
  assert system.index_register == 0x105
  assert vf == 0
}

pub fn add_idx_overflow_test() {
  // I = 0xFFF, V0 = 0x10, then I += V0 → I = 0x100F, VF = 1 (Amiga quirk:
  // VF set when I + VX leaves the 12-bit address space). I is not masked.
  let assert Ok(system) = chip8.new_system([0xAF, 0xFF, 0x60, 0x10, 0xF0, 0x1E])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  let assert Ok(vf) = dict.get(system.registers, 15)
  assert system.index_register == 0x100F
  assert vf == 1
}

pub fn jump_offset_test() {
  // V0 = 0x05, then BNNN with NNN=0x300 → PC = 0x300 + V0 = 0x305
  let assert Ok(system) = chip8.new_system([0x60, 0x05, 0xB3, 0x00])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  assert system.pc == 0x305
}

pub fn random_masked_to_zero_test() {
  // CXNN ANDs the random byte with NN. With NN=0 the result is always 0,
  // regardless of the random sample — guards against forgetting the mask.
  let assert Ok(system) = chip8.new_system([0xC0, 0x00])
  let assert Ok(system) = chip8.run(system)

  let assert Ok(v0) = dict.get(system.registers, 0)
  assert v0 == 0
}

pub fn random_bounded_test() {
  // CXNN with NN=0x0F must always produce a value in 0..15. Run 32 times
  // back-to-back so a buggy "ignore the mask" path is very likely to escape
  // the bound at least once.
  let rom = list.flatten(list.repeat([0xC0, 0x0F], 32))
  let assert Ok(system) = chip8.new_system(rom)

  int.range(from: 0, to: 32, with: system, run: fn(system, _) {
    let assert Ok(system) = chip8.run(system)
    let assert Ok(v0) = dict.get(system.registers, 0)
    assert v0 >= 0
    assert v0 <= 0x0F
    system
  })
  Nil
}

pub fn skip_pressed_taken_test() {
  // V0 = 5, key 5 is pressed; EX9E should skip → PC = 518
  let assert Ok(system) = chip8.new_system([0x60, 0x05, 0xE0, 0x9E])
  let system = chip8.System(..system, key_pressed: Some(5))
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  assert system.pc == 518
}

pub fn skip_pressed_not_taken_test() {
  // V0 = 5, key 7 is pressed (different key); EX9E should not skip → PC = 516.
  // Validates that the comparison checks the key value, not just Some/None.
  let assert Ok(system) = chip8.new_system([0x60, 0x05, 0xE0, 0x9E])
  let system = chip8.System(..system, key_pressed: Some(7))
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  assert system.pc == 516
}

pub fn skip_not_pressed_taken_test() {
  // V0 = 5, no key pressed; EXA1 should skip → PC = 518
  let assert Ok(system) = chip8.new_system([0x60, 0x05, 0xE0, 0xA1])
  let system = chip8.System(..system, key_pressed: None)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  assert system.pc == 518
}

pub fn skip_not_pressed_not_taken_test() {
  // V0 = 5, key 5 is pressed; EXA1 should not skip → PC = 516
  let assert Ok(system) = chip8.new_system([0x60, 0x05, 0xE0, 0xA1])
  let system = chip8.System(..system, key_pressed: Some(5))
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  assert system.pc == 516
}

pub fn get_key_waits_test() {
  // FX0A blocks until a key is released. With key_released = None, PC must
  // be rewound by 2 so the same instruction re-executes next tick, and Vx
  // must remain unchanged.
  let assert Ok(system) = chip8.new_system([0xF0, 0x0A])
  let system = chip8.System(..system, key_released: None)
  let assert Ok(system) = chip8.run(system)

  let assert Ok(v0) = dict.get(system.registers, 0)
  assert system.pc == 512
  assert v0 == 0
}

pub fn get_key_received_test() {
  // FX0A with key_released = Some(7) stores 7 in Vx and advances normally.
  let assert Ok(system) = chip8.new_system([0xF0, 0x0A])
  let system = chip8.System(..system, key_released: Some(7))
  let assert Ok(system) = chip8.run(system)

  let assert Ok(v0) = dict.get(system.registers, 0)
  assert system.pc == 514
  assert v0 == 7
}

pub fn set_reg_to_delay_test() {
  // FX07 copies the delay timer into Vx.
  let assert Ok(system) = chip8.new_system([0xF0, 0x07])
  let system = chip8.System(..system, delay_timer: 42)
  let assert Ok(system) = chip8.run(system)

  let assert Ok(v0) = dict.get(system.registers, 0)
  assert v0 == 42
}

pub fn set_delay_to_reg_test() {
  // V0 = 42, then FX15 copies V0 into the delay timer.
  let assert Ok(system) = chip8.new_system([0x60, 0x2A, 0xF0, 0x15])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  assert system.delay_timer == 42
}

pub fn set_sound_to_reg_test() {
  // V0 = 42, then FX18 copies V0 into the sound timer.
  let assert Ok(system) = chip8.new_system([0x60, 0x2A, 0xF0, 0x18])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  assert system.sound_timer == 42
}

pub fn set_font_char_test() {
  // V0 = 1, then FX29 sets I to the address of the '1' glyph in the font
  // table: font_location (80) + 1 * 5 = 85. The first byte of the '1' glyph
  // is 0x20.
  let assert Ok(system) = chip8.new_system([0x60, 0x01, 0xF0, 0x29])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)

  let assert Ok(font_byte) = iv.get(system.memory, system.index_register)
  assert system.index_register == 85
  assert font_byte == 0x20
}
