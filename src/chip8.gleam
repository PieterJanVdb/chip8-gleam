import gleam/bool
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/duration
import iv
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element/html
import lustre/event
import tiramisu
import tiramisu/camera
import tiramisu/material
import tiramisu/primitive
import tiramisu/renderer
import tiramisu/scene
import tiramisu/transform
import vec/vec3

const target_ips = 700.0

const delay_timer_step_ms = 16.666667

const memory_size = 4096

const screen_size = 2048

const font_location = 80

const pc_init_location = 512

const screen_width = 64

const screen_height = 32

const reg_vf = 15

const font = [
  0xF0,
  0x90,
  0x90,
  0x90,
  0xF0,
  // 0
  0x20,
  0x60,
  0x20,
  0x20,
  0x70,
  // 1
  0xF0,
  0x10,
  0xF0,
  0x80,
  0xF0,
  // 2
  0xF0,
  0x10,
  0xF0,
  0x10,
  0xF0,
  // 3
  0x90,
  0x90,
  0xF0,
  0x10,
  0x10,
  // 4
  0xF0,
  0x80,
  0xF0,
  0x10,
  0xF0,
  // 5
  0xF0,
  0x80,
  0xF0,
  0x90,
  0xF0,
  // 6
  0xF0,
  0x10,
  0x20,
  0x40,
  0x40,
  // 7
  0xF0,
  0x90,
  0xF0,
  0x90,
  0xF0,
  // 8
  0xF0,
  0x90,
  0xF0,
  0x10,
  0xF0,
  // 9
  0xF0,
  0x90,
  0xF0,
  0x90,
  0x90,
  // A
  0xE0,
  0x90,
  0xE0,
  0x90,
  0xE0,
  // B
  0xF0,
  0x80,
  0x80,
  0x80,
  0xF0,
  // C
  0xE0,
  0x90,
  0x90,
  0x90,
  0xE0,
  // D
  0xF0,
  0x80,
  0xF0,
  0x80,
  0xF0,
  // E
  0xF0,
  0x80,
  0xF0,
  0x80,
  0x80,
  // F 
]

pub type SystemError {
  FetchError
  DecodeError(BitArray)
  RegisterNotFoundError
  ScreenOutOfBoundsError
  MemoryOutOfBoundsError
  InvalidReturnError
  LoadROMError
}

pub type System {
  System(
    memory: iv.Array(Int),
    index_register: Int,
    pc: Int,
    screen: iv.Array(Bool),
    stack: List(Int),
    delay_timer: Int,
    sound_timer: Int,
    registers: dict.Dict(Int, Int),
    key_pressed: Option(Int),
    key_released: Option(Int),
  )
}

pub type ShiftDirection {
  ShiftLeft
  ShiftRight
}

pub type Instruction {
  Clear
  Call(address: Int)
  Jump(address: Int)
  JumpOffset(address: Int)
  Return
  SetRegToVal(reg: Int, value: Int)
  AddValToReg(reg: Int, value: Int)
  SetIdx(address: Int)
  AddIdx(reg: Int)
  Display(reg_x: Int, reg_y: Int, height: Int)
  SkipValEq(reg: Int, value: Int, equality: Bool)
  SkipRegEq(reg_x: Int, reg_y: Int, equality: Bool)
  SetXToY(reg_x: Int, reg_y: Int)
  Or(reg_x: Int, reg_y: Int)
  And(reg_x: Int, reg_y: Int)
  Xor(reg_x: Int, reg_y: Int)
  AddYToX(reg_x: Int, reg_y: Int)
  SubYFromX(reg_x: Int, reg_y: Int)
  SubXFromY(reg_x: Int, reg_y: Int)
  Shift(reg_x: Int, to: ShiftDirection)
  Store(reg: Int)
  Load(reg: Int)
  Bcd(reg: Int)
  Random(reg: Int, value: Int)
  SkipPressed(reg: Int)
  SkipNotPressed(reg: Int)
  GetKey(reg: Int)
  SetRegToDelay(reg: Int)
  SetDelayToReg(reg: Int)
  SetSoundToReg(reg: Int)
  SetFontChar(reg: Int)
}

// SYSTEM

pub fn new_system(rom: List(Int)) -> Result(System, SystemError) {
  let assert Ok(memory) =
    iv.repeat(0, times: memory_size)
    |> iv.replace(
      at: font_location,
      replace: list.length(font),
      with: iv.from_list(font),
    )

  use memory <- result.try(
    iv.replace(
      memory,
      at: pc_init_location,
      replace: list.length(rom),
      with: iv.from_list(rom),
    )
    |> result.replace_error(LoadROMError),
  )

  Ok(System(
    pc: pc_init_location,
    screen: iv.repeat(False, times: screen_size),
    index_register: 0,
    stack: [],
    delay_timer: 360,
    sound_timer: 0,
    registers: int.range(from: 0, to: 16, with: dict.new(), run: fn(acc, i) {
      dict.insert(acc, i, 0)
    }),
    memory:,
    key_pressed: None,
    key_released: None,
  ))
}

fn clear_screen(system: System) -> System {
  System(..system, screen: iv.repeat(False, times: screen_size))
}

fn get_byte_at(memory: iv.Array(Int), at at: Int) -> Result(Int, SystemError) {
  iv.get(memory, at) |> result.replace_error(MemoryOutOfBoundsError)
}

fn set_pixel(
  screen: iv.Array(Bool),
  at at: Int,
  to to: Bool,
) -> Result(iv.Array(Bool), SystemError) {
  iv.set(screen, at, to) |> result.replace_error(ScreenOutOfBoundsError)
}

fn get_pixel(screen: iv.Array(Bool), at at: Int) -> Result(Bool, SystemError) {
  iv.get(screen, at) |> result.replace_error(ScreenOutOfBoundsError)
}

fn get_register(
  registers: dict.Dict(Int, Int),
  reg reg: Int,
) -> Result(Int, SystemError) {
  dict.get(registers, reg) |> result.replace_error(RegisterNotFoundError)
}

fn set_register(
  registers: dict.Dict(Int, Int),
  reg reg: Int,
  to to: Int,
) -> Result(dict.Dict(Int, Int), SystemError) {
  use <- bool.guard(
    !dict.has_key(registers, reg),
    return: Error(RegisterNotFoundError),
  )
  Ok(dict.insert(registers, reg, to))
}

fn get_register_range(
  registers: dict.Dict(Int, Int),
  size size: Int,
) -> Result(List(Int), SystemError) {
  int.range(from: size - 1, to: -1, with: [], run: fn(range, reg) {
    [dict.get(registers, reg), ..range]
  })
  |> result.all()
  |> result.replace_error(RegisterNotFoundError)
}

fn store_register_range(
  registers: dict.Dict(Int, Int),
  range range: List(Int),
) -> Result(dict.Dict(Int, Int), SystemError) {
  list.index_map(range, fn(val, i) { #(val, i) })
  |> list.try_fold(from: registers, with: fn(acc, x) {
    let #(val, i) = x
    set_register(acc, reg: i, to: val)
  })
}

fn get_memory_range(memory: iv.Array(Int), from from: Int, size size: Int) {
  iv.slice(from: memory, start: from, size:)
  |> result.map(iv.to_list)
  |> result.replace_error(MemoryOutOfBoundsError)
}

fn store_memory_range(
  memory: iv.Array(Int),
  from from: Int,
  range range: List(Int),
) {
  list.index_map(range, fn(val, i) { #(val, i) })
  |> list.try_fold(from: memory, with: fn(acc, x) {
    let #(val, i) = x
    iv.set(in: acc, at: from + i, to: val)
    |> result.replace_error(MemoryOutOfBoundsError)
  })
}

fn wrap_byte(n: Int) -> Int {
  int.bitwise_and(n, 0xFF)
}

fn carry_flag(n: Int) -> Int {
  case n > 255 {
    True -> 1
    False -> 0
  }
}

fn borrow_flag(n: Int) -> Int {
  case n < 0 {
    True -> 0
    False -> 1
  }
}

fn write_arith(
  system: System,
  reg reg: Int,
  raw raw: Int,
  flag flag: fn(Int) -> Int,
) -> Result(System, SystemError) {
  use registers <- result.try(set_register(
    system.registers,
    reg,
    wrap_byte(raw),
  ))
  use registers <- result.try(set_register(registers, reg_vf, flag(raw)))
  Ok(System(..system, registers:))
}

fn display(
  system: System,
  reg_x reg_x: Int,
  reg_y reg_y: Int,
  height height: Int,
) -> Result(System, SystemError) {
  use vx <- result.try(get_register(system.registers, reg: reg_x))
  use vy <- result.try(get_register(system.registers, reg: reg_y))

  let x = int.bitwise_and(vx, screen_width - 1)
  let y = int.bitwise_and(vy, screen_height - 1)

  use registers <- result.try(set_register(system.registers, reg: reg_vf, to: 0))
  let system = System(..system, registers:)

  display_loop(system, x, y, height, 0)
}

fn display_loop(
  system: System,
  x: Int,
  y: Int,
  height: Int,
  row: Int,
) -> Result(System, SystemError) {
  case row >= height || y >= screen_height {
    True -> Ok(system)
    False -> {
      use sprite_byte <- result.try(get_byte_at(
        system.memory,
        at: system.index_register + row,
      ))
      use system <- result.try(draw_row(system, x, y, sprite_byte))
      display_loop(system, x, y + 1, height, row + 1)
    }
  }
}

fn draw_row(
  system: System,
  x: Int,
  y: Int,
  sprite_byte: Int,
) -> Result(System, SystemError) {
  let assert <<b0:1, b1:1, b2:1, b3:1, b4:1, b5:1, b6:1, b7:1>> = <<
    sprite_byte,
  >>
  draw_row_loop(system, x, y, [
    b0 == 1,
    b1 == 1,
    b2 == 1,
    b3 == 1,
    b4 == 1,
    b5 == 1,
    b6 == 1,
    b7 == 1,
  ])
}

fn draw_row_loop(
  system: System,
  x: Int,
  y: Int,
  bits: List(Bool),
) -> Result(System, SystemError) {
  case bits {
    _ if x >= screen_width -> Ok(system)
    [] -> Ok(system)
    [sprite_pixel, ..rest] -> {
      use system <- result.try(draw_pixel(system, x, y, sprite_pixel))
      draw_row_loop(system, x + 1, y, rest)
    }
  }
}

fn draw_pixel(
  system: System,
  x: Int,
  y: Int,
  sprite_pixel: Bool,
) -> Result(System, SystemError) {
  let pixel_idx = y * screen_width + x
  use current_pixel <- result.try(get_pixel(system.screen, at: pixel_idx))

  let new_pixel = current_pixel != sprite_pixel
  let collision = current_pixel && sprite_pixel

  use screen <- result.try(set_pixel(
    system.screen,
    at: pixel_idx,
    to: new_pixel,
  ))

  use <- bool.guard(when: !collision, return: Ok(System(..system, screen:)))
  use registers <- result.try(set_register(system.registers, reg: reg_vf, to: 1))
  Ok(System(..system, screen:, registers:))
}

fn fetch(system: System) -> Result(#(System, BitArray), SystemError) {
  case
    get_byte_at(system.memory, at: system.pc),
    get_byte_at(system.memory, at: system.pc + 1)
  {
    Ok(x), Ok(y) -> Ok(#(System(..system, pc: system.pc + 2), <<x, y>>))
    _, _ -> Error(MemoryOutOfBoundsError)
  }
}

fn decode(instruction_arr: BitArray) -> Result(Instruction, SystemError) {
  case instruction_arr {
    // 00E0
    <<0x0:4, 0x0:4, 0xE:4, 0x0:4>> -> Ok(Clear)
    // 00EE
    <<0x0:4, 0x0:4, 0xE:4, 0xE:4>> -> Ok(Return)
    // 1NNN
    <<0x1:4, address:12>> -> Ok(Jump(address:))
    // 2NNN
    <<0x2:4, address:12>> -> Ok(Call(address:))
    // 3XNN
    <<0x3:4, reg:4, value:8>> -> Ok(SkipValEq(reg:, value:, equality: True))
    // 4XNN
    <<0x4:4, reg:4, value:8>> -> Ok(SkipValEq(reg:, value:, equality: False))
    // 5XY0
    <<0x5:4, reg_x:4, reg_y:4, 0x0:4>> ->
      Ok(SkipRegEq(reg_x:, reg_y:, equality: True))
    // 6XNN
    <<0x6:4, reg:4, value:8>> -> Ok(SetRegToVal(reg:, value:))
    // 7XNN
    <<0x7:4, reg:4, value:8>> -> Ok(AddValToReg(reg:, value:))
    // 9XY0
    <<0x9:4, reg_x:4, reg_y:4, 0x0:4>> ->
      Ok(SkipRegEq(reg_x:, reg_y:, equality: False))
    // ANNN
    <<0xA:4, address:12>> -> Ok(SetIdx(address:))
    // BNNN
    <<0xB:4, address:12>> -> Ok(JumpOffset(address:))
    // CXNN
    <<0xC:4, reg:4, value:8>> -> Ok(Random(reg:, value:))
    // DXYN
    <<0xD:4, reg_x:4, reg_y:4, height:4>> ->
      Ok(Display(reg_x:, reg_y:, height:))
    // EX9E
    <<0xE:4, reg:4, 0x9:4, 0xE:4>> -> Ok(SkipPressed(reg:))
    // EXA1
    <<0xE:4, reg:4, 0xA:4, 0x1:4>> -> Ok(SkipNotPressed(reg:))
    // FX07
    <<0xF:4, reg:4, 0x0:4, 0x7:4>> -> Ok(SetRegToDelay(reg:))
    // FX15
    <<0xF:4, reg:4, 0x1:4, 0x5:4>> -> Ok(SetDelayToReg(reg:))
    // FX18
    <<0xF:4, reg:4, 0x1:4, 0x8:4>> -> Ok(SetSoundToReg(reg:))
    // FX1E
    <<0xF:4, reg:4, 0x1:4, 0xE:4>> -> Ok(AddIdx(reg:))
    // FX29
    <<0xF:4, reg:4, 0x2:4, 0x9:4>> -> Ok(SetFontChar(reg:))
    // FX33
    <<0xF:4, reg:4, 0x3:4, 0x3:4>> -> Ok(Bcd(reg:))
    // FX55
    <<0xF:4, reg:4, 0x5:4, 0x5:4>> -> Ok(Store(reg:))
    // FX65
    <<0xF:4, reg:4, 0x6:4, 0x5:4>> -> Ok(Load(reg:))
    // FX0A
    <<0xF:4, reg:4, 0x0:4, 0xA:4>> -> Ok(GetKey(reg:))
    // 8XY_ Logical and arithmetic instructions
    <<0x8:4, reg_x:4, reg_y:4, op:4>> as instr -> {
      case op {
        0x0 -> Ok(SetXToY(reg_x:, reg_y:))
        0x1 -> Ok(Or(reg_x:, reg_y:))
        0x2 -> Ok(And(reg_x:, reg_y:))
        0x3 -> Ok(Xor(reg_x:, reg_y:))
        0x4 -> Ok(AddYToX(reg_x:, reg_y:))
        0x5 -> Ok(SubYFromX(reg_x:, reg_y:))
        0x6 -> Ok(Shift(reg_x:, to: ShiftRight))
        0x7 -> Ok(SubXFromY(reg_x:, reg_y:))
        0xE -> Ok(Shift(reg_x:, to: ShiftLeft))
        _ -> Error(DecodeError(instr))
      }
    }
    instr -> Error(DecodeError(instr))
  }
}

fn execute(
  system: System,
  instruction: Instruction,
) -> Result(System, SystemError) {
  case instruction {
    Clear -> Ok(clear_screen(system))
    Call(address:) -> {
      let stack = list.prepend(system.stack, system.pc)
      Ok(System(..system, stack:, pc: address))
    }
    Return -> {
      case system.stack {
        [next_pc, ..rest] -> {
          Ok(System(..system, stack: rest, pc: next_pc))
        }
        _ -> Error(InvalidReturnError)
      }
    }
    Jump(address:) -> Ok(System(..system, pc: address))
    SetRegToVal(reg:, value:) -> {
      use registers <- result.try(set_register(
        system.registers,
        reg:,
        to: value,
      ))
      Ok(System(..system, registers:))
    }
    AddValToReg(reg:, value:) -> {
      use vx <- result.try(get_register(system.registers, reg))
      use registers <- result.try(set_register(
        system.registers,
        reg,
        wrap_byte(vx + value),
      ))
      Ok(System(..system, registers:))
    }
    SetIdx(address:) -> {
      Ok(System(..system, index_register: address))
    }
    Display(reg_x:, reg_y:, height:) -> display(system, reg_x:, reg_y:, height:)
    SkipValEq(reg:, value:, equality:) -> {
      use reg_value <- result.try(get_register(system.registers, reg))
      use <- bool.guard({ reg_value == value } != equality, return: Ok(system))
      Ok(System(..system, pc: system.pc + 2))
    }
    SkipRegEq(reg_x:, reg_y:, equality:) -> {
      use vx <- result.try(get_register(system.registers, reg_x))
      use vy <- result.try(get_register(system.registers, reg_y))
      use <- bool.guard({ vx == vy } != equality, return: Ok(system))
      Ok(System(..system, pc: system.pc + 2))
    }
    SetXToY(reg_x:, reg_y:) -> {
      use vy <- result.try(get_register(system.registers, reg_y))
      use registers <- result.try(set_register(
        system.registers,
        reg: reg_x,
        to: vy,
      ))
      Ok(System(..system, registers:))
    }
    Or(reg_x:, reg_y:) -> {
      use vx <- result.try(get_register(system.registers, reg_x))
      use vy <- result.try(get_register(system.registers, reg_y))
      use registers <- result.try(set_register(
        system.registers,
        reg: reg_x,
        to: int.bitwise_or(vx, vy),
      ))
      Ok(System(..system, registers:))
    }
    And(reg_x:, reg_y:) -> {
      use vx <- result.try(get_register(system.registers, reg_x))
      use vy <- result.try(get_register(system.registers, reg_y))
      use registers <- result.try(set_register(
        system.registers,
        reg: reg_x,
        to: int.bitwise_and(vx, vy),
      ))
      Ok(System(..system, registers:))
    }
    Xor(reg_x:, reg_y:) -> {
      use vx <- result.try(get_register(system.registers, reg_x))
      use vy <- result.try(get_register(system.registers, reg_y))
      use registers <- result.try(set_register(
        system.registers,
        reg: reg_x,
        to: int.bitwise_exclusive_or(vx, vy),
      ))
      Ok(System(..system, registers:))
    }
    AddYToX(reg_x:, reg_y:) -> {
      use vx <- result.try(get_register(system.registers, reg_x))
      use vy <- result.try(get_register(system.registers, reg_y))
      write_arith(system, reg: reg_x, raw: vx + vy, flag: carry_flag)
    }
    SubYFromX(reg_x:, reg_y:) -> {
      use vx <- result.try(get_register(system.registers, reg_x))
      use vy <- result.try(get_register(system.registers, reg_y))
      write_arith(system, reg: reg_x, raw: vx - vy, flag: borrow_flag)
    }
    SubXFromY(reg_x:, reg_y:) -> {
      use vx <- result.try(get_register(system.registers, reg_x))
      use vy <- result.try(get_register(system.registers, reg_y))
      write_arith(system, reg: reg_x, raw: vy - vx, flag: borrow_flag)
    }
    Shift(reg_x:, to:) -> {
      use vx <- result.try(get_register(system.registers, reg_x))

      case to {
        ShiftRight -> {
          // Using bitarray matching here to avoid BigInt
          let assert <<rest:7, lsb:1>> = <<vx>>
          let assert <<new_vx:8>> = <<0:1, rest:7>>
          use registers <- result.try(set_register(
            system.registers,
            reg_x,
            new_vx,
          ))
          use registers <- result.try(set_register(registers, reg_vf, lsb))
          Ok(System(..system, registers:))
        }
        ShiftLeft -> {
          // Using bitarray matching here to avoid BigInt
          let assert <<msb:1, rest:7>> = <<vx>>
          let assert <<new_vx:8>> = <<rest:7, 0:1>>
          use registers <- result.try(set_register(
            system.registers,
            reg_x,
            new_vx,
          ))
          use registers <- result.try(set_register(registers, reg_vf, msb))
          Ok(System(..system, registers:))
        }
      }
    }
    Store(reg:) -> {
      use range <- result.try(get_register_range(
        system.registers,
        size: reg + 1,
      ))
      use memory <- result.try(store_memory_range(
        system.memory,
        from: system.index_register,
        range:,
      ))

      Ok(System(..system, memory:))
    }
    Load(reg:) -> {
      use range <- result.try(get_memory_range(
        system.memory,
        from: system.index_register,
        size: reg + 1,
      ))
      use registers <- result.try(store_register_range(system.registers, range:))
      Ok(System(..system, registers:))
    }
    Bcd(reg:) -> {
      use vx <- result.try(get_register(system.registers, reg:))

      let hundreds = vx / 100
      let tens = vx / 10 % 10
      let ones = vx % 10

      use memory <- result.try(
        store_memory_range(system.memory, from: system.index_register, range: [
          hundreds,
          tens,
          ones,
        ]),
      )

      Ok(System(..system, memory:))
    }
    AddIdx(reg:) -> {
      use vx <- result.try(get_register(system.registers, reg:))
      let sum = system.index_register + vx

      use registers <- result.try(
        set_register(system.registers, reg_vf, case sum > 0xFFF {
          True -> 1
          False -> 0
        }),
      )

      Ok(System(..system, index_register: sum, registers:))
    }
    JumpOffset(address:) -> {
      use offset <- result.try(get_register(system.registers, reg: 0))
      Ok(System(..system, pc: address + offset))
    }
    Random(reg:, value:) -> {
      use registers <- result.try(set_register(
        system.registers,
        reg:,
        to: int.random(255) |> int.bitwise_and(value),
      ))
      Ok(System(..system, registers:))
    }
    SkipPressed(reg:) -> {
      use vkey <- result.try(get_register(system.registers, reg:))

      case system.key_pressed {
        Some(key) if key == vkey -> Ok(System(..system, pc: system.pc + 2))
        _ -> Ok(system)
      }
    }
    SkipNotPressed(reg:) -> {
      use vkey <- result.try(get_register(system.registers, reg:))

      case system.key_pressed {
        Some(key) if key == vkey -> Ok(system)
        _ -> Ok(System(..system, pc: system.pc + 2))
      }
    }
    GetKey(reg:) -> {
      case system.key_released {
        Some(key) -> {
          use registers <- result.try(set_register(
            system.registers,
            reg:,
            to: key,
          ))
          Ok(System(..system, registers:))
        }
        _ -> Ok(System(..system, pc: system.pc - 2))
      }
    }
    SetRegToDelay(reg:) -> {
      use registers <- result.try(set_register(
        system.registers,
        reg:,
        to: system.delay_timer,
      ))
      Ok(System(..system, registers:))
    }
    SetDelayToReg(reg:) -> {
      use vx <- result.try(get_register(system.registers, reg:))
      Ok(System(..system, delay_timer: vx))
    }
    SetSoundToReg(reg:) -> {
      use vx <- result.try(get_register(system.registers, reg:))
      Ok(System(..system, sound_timer: vx))
    }
    SetFontChar(reg:) -> {
      use vx <- result.try(get_register(system.registers, reg:))
      Ok(System(..system, index_register: font_location + vx * 5))
    }
  }
}

pub fn run(system: System) -> Result(System, SystemError) {
  use #(system, instruction_arr) <- result.try(fetch(system))
  use instruction <- result.try(decode(instruction_arr))
  use system <- result.try(execute(system, instruction))

  Ok(system)
}

fn run_n(system: System, n: Int) -> Result(System, SystemError) {
  case n {
    0 -> Ok(system)
    _ -> {
      use system <- result.try(run(system))
      run_n(system, n - 1)
    }
  }
}

// LUSTRE / TIRAMISU

pub type RomLoadedModel {
  RomLoadedModel(system: System, accumulator_ms: Float, beeper: Beeper)
}

pub type Model {
  RomLoaded(RomLoadedModel)
  RomPending
}

pub type Msg {
  Tick(renderer.Tick)
  UserSelectedRom(RomFile)
  RomFileRead(List(Int))
  UserPressedKey(String)
  UserReleasedKey(String)
}

pub fn main() -> Nil {
  let assert Ok(_) = tiramisu.register(tiramisu.builtin_extensions())
  let assert Ok(_) =
    lustre.application(init:, update:, view:) |> lustre.start("#app", Nil)
  Nil
}

fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  #(init_model(), register_key_handlers())
}

fn init_model() -> Model {
  RomPending
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Tick(tick) -> {
      case model {
        RomLoaded(model) -> handle_tick(model, tick)
        RomPending -> #(model, effect.none())
      }
    }
    UserSelectedRom(rom_file) -> #(model, read_rom_file(rom_file))
    RomFileRead(bytes) -> {
      case new_system(bytes) {
        Ok(system) -> #(
          RomLoaded(RomLoadedModel(
            system:,
            accumulator_ms: 0.0,
            beeper: create_beeper(),
          )),
          effect.none(),
        )
        Error(_) -> #(model, effect.none())
      }
    }
    UserPressedKey(code) -> {
      case model {
        RomLoaded(model) -> {
          case code_to_key(code) {
            Ok(key) -> #(RomLoaded(key_pressed(model, key)), effect.none())
            Error(_) -> #(RomLoaded(model), effect.none())
          }
        }
        RomPending -> #(model, effect.none())
      }
    }
    UserReleasedKey(code) -> {
      case model {
        RomLoaded(model) -> {
          case code_to_key(code) {
            Ok(key) -> #(RomLoaded(key_released(model, key)), effect.none())
            Error(_) -> #(RomLoaded(model), effect.none())
          }
        }
        RomPending -> #(model, effect.none())
      }
    }
  }
}

fn view(model: Model) {
  html.main(
    [
      attribute.class(
        "min-h-screen flex flex-col items-center gap-6 p-8 bg-theme-bg text-theme-fg font-mono",
      ),
    ],
    [
      html.header([], [
        html.h1(
          [attribute.class("text-6xl tracking-widest text-theme-accent")],
          [html.text("CHIP-8")],
        ),
      ]),
      html.label(
        [
          attribute.class(
            "cursor-pointer border border-theme-accent text-theme-accent px-6 py-2 text-2xl tracking-wider hover:bg-theme-accent hover:text-theme-bg transition-colors",
          ),
        ],
        [
          html.text("[ LOAD ROM ]"),
          html.input([
            attribute.class("sr-only"),
            attribute.type_("file"),
            attribute.accept([".ch8", "application/octet-stream"]),
            event.on("change", decode.map(file_decoder(), UserSelectedRom)),
          ]),
        ],
      ),
      html.div([attribute.class("border border-theme-accent")], [
        tiramisu.renderer(
          "renderer",
          [
            renderer.width(screen_width * 10),
            renderer.height(screen_height * 10),
            renderer.on_tick(Tick),
          ],
          [
            tiramisu.scene("scene", [scene.background_color(0x1A1816)], [
              tiramisu.camera(
                "camera",
                [
                  camera.active(True),
                  camera.orthographic(),
                  camera.left(0.0),
                  camera.right(int.to_float(screen_width)),
                  camera.top(0.0),
                  camera.bottom(int.to_float(screen_height)),
                  camera.near(0.1),
                  camera.far(100.0),
                  transform.position(vec3.Vec3(0.0, 0.0, 20.0)),
                ],
                [],
              ),
              tiramisu.empty("screen", [], {
                case model {
                  RomPending -> []
                  RomLoaded(model) -> {
                    let pixel_geom = primitive.box(vec3.Vec3(1.0, 1.0, 0.0))
                    iv.index_map(model.system.screen, fn(on, idx) {
                      let #(x, y) = index_to_coords(idx)

                      tiramisu.primitive(
                        "pixel-" <> int.to_string(idx),
                        [
                          pixel_geom,
                          material.basic(),
                          material.color(pixel_state_to_color(on)),
                          transform.position(vec3.Vec3(x, y, 0.0)),
                        ],
                        [],
                      )
                    })
                    |> iv.to_list
                  }
                }
              }),
            ]),
          ],
        ),
      ]),
      html.p([attribute.class("text-lg text-theme-muted")], [
        html.text("Keys: 1234 / QWER / ASDF / ZXCV"),
      ]),
      html.footer([attribute.class("mt-auto text-lg text-theme-muted")], [
        html.text("Made by Pieter-Jan"),
      ]),
    ],
  )
}

pub type RomFile

fn file_decoder() -> decode.Decoder(RomFile) {
  decode.new_primitive_decoder("RomFile", file_from_on_change)
}

fn read_rom_file(rom_file: RomFile) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    let _ =
      read_bytes(rom_file)
      |> promise.tap(fn(bytes) { dispatch(RomFileRead(bytes)) })
    Nil
  })
}

@external(javascript, "./app_ffi.mjs", "fileFromOnChange")
fn file_from_on_change(event: dynamic.Dynamic) -> Result(RomFile, RomFile)

@external(javascript, "./app_ffi.mjs", "readBytes")
fn read_bytes(file: RomFile) -> Promise(List(Int))

fn index_to_coords(idx: Int) -> #(Float, Float) {
  let x = { idx % screen_width } |> int.to_float() |> float.add(0.5)
  let y = { idx / screen_width } |> int.to_float() |> float.add(0.5)

  #(x, y)
}

fn pixel_state_to_color(on: Bool) -> Int {
  case on {
    True -> 0xC5A572
    False -> 0x0F0D0B
  }
}

fn handle_tick(
  model: RomLoadedModel,
  tick: renderer.Tick,
) -> #(Model, Effect(a)) {
  // Tick should run about 60 times per second, so we try to run
  // n instructions in a single tick to get to about 700 IPS
  let n_instructions = get_n_frame_instructions(tick.delta_time)
  let model = handle_timers(model, delta: tick.delta_time)

  case run_n(model.system, n_instructions) {
    Ok(system) -> {
      let _ = case model.system.sound_timer > 0 {
        True -> start_beeper(model.beeper)
        False -> stop_beeper(model.beeper)
      }

      #(
        RomLoaded(
          RomLoadedModel(..model, system: System(..system, key_released: None)),
        ),
        effect.none(),
      )
    }
    Error(err) -> {
      echo err as "Uh oh"
      #(RomLoaded(model), effect.none())
    }
  }
}

fn get_n_frame_instructions(delta delta: duration.Duration) -> Int {
  let delta = duration.to_seconds(delta)
  let clamped_delta = float.min(delta, 0.1)
  float.round(target_ips *. clamped_delta)
}

fn handle_timers(
  model: RomLoadedModel,
  delta delta: duration.Duration,
) -> RomLoadedModel {
  let delta_ms = duration.to_seconds(delta) *. 1000.0
  let acc = model.accumulator_ms +. delta_ms

  // How many whole 1/60s steps fit into the accumulator?
  let steps = float.truncate(acc /. delay_timer_step_ms)
  let leftover = acc -. int.to_float(steps) *. delay_timer_step_ms

  RomLoadedModel(
    ..model,
    system: System(
      ..model.system,
      delay_timer: int.max(0, model.system.delay_timer - 1),
      sound_timer: int.max(0, model.system.sound_timer - 1),
    ),
    accumulator_ms: leftover,
  )
}

pub type Beeper

@external(javascript, "./app_ffi.mjs", "createBeeper")
fn create_beeper() -> Beeper

@external(javascript, "./app_ffi.mjs", "startBeeper")
fn start_beeper(beeper: Beeper) -> Nil

@external(javascript, "./app_ffi.mjs", "stopBeeper")
fn stop_beeper(beeper: Beeper) -> Nil

fn register_key_handlers() {
  effect.from(fn(dispatch) {
    do_register_key_handlers(
      fn(code) { dispatch(UserPressedKey(code)) },
      fn(code) { dispatch(UserReleasedKey(code)) },
    )
  })
}

@external(javascript, "./app_ffi.mjs", "registerKeyHandlers")
fn do_register_key_handlers(
  on_keydown: fn(String) -> Nil,
  on_keyup: fn(String) -> Nil,
) -> Nil

fn key_pressed(model: RomLoadedModel, key: Int) {
  RomLoadedModel(
    ..model,
    system: System(..model.system, key_pressed: Some(key)),
  )
}

fn key_released(model: RomLoadedModel, key: Int) {
  case model.system.key_pressed {
    Some(pressed) if pressed == key -> {
      RomLoadedModel(
        ..model,
        system: System(
          ..model.system,
          key_pressed: None,
          key_released: Some(key),
        ),
      )
    }
    _ -> model
  }
}

fn code_to_key(code: String) -> Result(Int, Nil) {
  case code {
    "Digit1" -> Ok(0x1)
    "Digit2" -> Ok(0x2)
    "Digit3" -> Ok(0x3)
    "Digit4" -> Ok(0xC)
    "KeyQ" -> Ok(0x4)
    "KeyW" -> Ok(0x5)
    "KeyE" -> Ok(0x6)
    "KeyR" -> Ok(0xD)
    "KeyA" -> Ok(0x7)
    "KeyS" -> Ok(0x8)
    "KeyD" -> Ok(0x9)
    "KeyF" -> Ok(0xE)
    "KeyZ" -> Ok(0xA)
    "KeyX" -> Ok(0x0)
    "KeyC" -> Ok(0xB)
    "KeyV" -> Ok(0xF)
    _ -> Error(Nil)
  }
}
