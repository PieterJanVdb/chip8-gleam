import chip8
import gleam/dict
import gleam/list
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
  assert chip8.run(system) == Error(chip8.DecodeError)
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
  let assert Ok(system) =
    chip8.new_system([0x60, 0xAA, 0x61, 0xF0, 0x80, 0x11])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  assert v0 == 0xFA
}

pub fn and_test() {
  // V0 = 0xAA, V1 = 0xF0, then V0 &= V1 → 0xA0
  let assert Ok(system) =
    chip8.new_system([0x60, 0xAA, 0x61, 0xF0, 0x80, 0x12])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  assert v0 == 0xA0
}

pub fn xor_test() {
  // V0 = 0xAA, V1 = 0xF0, then V0 ^= V1 → 0x5A
  let assert Ok(system) =
    chip8.new_system([0x60, 0xAA, 0x61, 0xF0, 0x80, 0x13])
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(system) = chip8.run(system)
  let assert Ok(v0) = dict.get(system.registers, 0)
  assert v0 == 0x5A
}

pub fn add_y_to_x_test() {
  // V0 = 5, V1 = 3, then V0 += V1 → 8, VF = 0
  let assert Ok(system) =
    chip8.new_system([0x60, 0x05, 0x61, 0x03, 0x80, 0x14])
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
  let assert Ok(system) =
    chip8.new_system([0x60, 0xFF, 0x61, 0x01, 0x80, 0x14])
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
  let assert Ok(system) =
    chip8.new_system([0x60, 0x05, 0x61, 0x03, 0x80, 0x15])
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
  let assert Ok(system) =
    chip8.new_system([0x60, 0x03, 0x61, 0x05, 0x80, 0x15])
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
  let assert Ok(system) =
    chip8.new_system([0x60, 0x03, 0x61, 0x05, 0x80, 0x17])
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
  let assert Ok(system) =
    chip8.new_system([0x60, 0x05, 0x61, 0x03, 0x80, 0x17])
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
