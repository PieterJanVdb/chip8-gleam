import chip8
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn run_test() {
  let rom = [0, 224, 162, 42, 96, 12, 97, 8]
  let assert Ok(system) = chip8.new_system(rom)

  // clear
  let assert Ok(system) = chip8.run(system)
  echo #(system.pc, system.index_register, system.registers)

  // setidx
  let assert Ok(system) = chip8.run(system)
  echo #(system.pc, system.index_register, system.registers)

  // set reg 0
  let assert Ok(system) = chip8.run(system)
  echo #(system.pc, system.index_register, system.registers)

  // set reg 1
  let assert Ok(system) = chip8.run(system)
  echo #(system.pc, system.index_register, system.registers)
}
