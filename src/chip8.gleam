import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{None, Some}
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
import tiramisu/transform
import vec/vec3

const target_ips = 700.0

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
  DecodeError
  RegisterNotFoundError
  ScreenOutOfBoundsError
  MemoryOutOfBoundsError
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
  )
}

pub type Instruction {
  Clear
  Jump(address: Int)
  Set(reg: Int, value: Int)
  Add(reg: Int, value: Int)
  SetIdx(address: Int)
  Display(reg_x: Int, reg_y: Int, height: Int)
}

// SYSTEM

pub fn new_system() -> System {
  let assert Ok(memory) =
    iv.repeat(0, times: memory_size)
    |> iv.replace(
      at: font_location,
      replace: list.length(font),
      with: iv.from_list(font),
    )

  System(
    pc: pc_init_location,
    screen: iv.repeat(False, times: screen_size),
    index_register: 0,
    stack: [],
    delay_timer: 0,
    sound_timer: 0,
    registers: dict.new(),
    memory:,
  )
}

fn clear_screen(system: System) -> System {
  System(..system, screen: iv.repeat(False, times: screen_size))
}

pub fn load_rom(system: System, rom: List(Int)) -> Result(System, SystemError) {
  use memory <- result.try(
    iv.replace(
      system.memory,
      at: pc_init_location,
      replace: list.length(rom),
      with: iv.from_list(rom),
    )
    |> result.replace_error(LoadROMError),
  )

  Ok(System(..system, memory:))
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
) -> dict.Dict(Int, Int) {
  dict.insert(registers, reg, to)
}

fn inc_register(
  registers: dict.Dict(Int, Int),
  reg reg: Int,
  with with: Int,
) -> dict.Dict(Int, Int) {
  dict.upsert(registers, reg, fn(x) {
    case x {
      Some(i) -> i + with
      None -> with
    }
  })
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

  let registers = set_register(system.registers, reg: reg_vf, to: 0)
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
  let registers = case collision {
    True -> set_register(system.registers, reg: reg_vf, to: 1)
    False -> system.registers
  }

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
    <<0:4, 0:4, 14:4, 0:4>> -> Ok(Clear)
    <<1:4, address:12>> -> Ok(Jump(address:))
    <<6:4, reg:4, value>> -> Ok(Set(reg:, value:))
    <<7:4, reg:4, value>> -> Ok(Add(reg:, value:))
    <<10:4, address:12>> -> Ok(SetIdx(address:))
    <<13:4, reg_x:4, reg_y:4, height:4>> -> Ok(Display(reg_x:, reg_y:, height:))
    _ -> Error(DecodeError)
  }
}

fn execute(
  system: System,
  instruction: Instruction,
) -> Result(System, SystemError) {
  case instruction {
    Clear -> Ok(clear_screen(system))
    Jump(address:) -> Ok(System(..system, pc: address))
    Set(reg:, value:) -> {
      let registers = set_register(system.registers, reg:, to: value)
      Ok(System(..system, registers:))
    }
    Add(reg:, value:) -> {
      let registers = inc_register(system.registers, reg:, with: value)
      Ok(System(..system, registers:))
    }
    SetIdx(address:) -> {
      Ok(System(..system, index_register: address))
    }
    Display(reg_x:, reg_y:, height:) -> display(system, reg_x:, reg_y:, height:)
  }
}

pub fn run(system: System) -> Result(System, SystemError) {
  use #(system, instruction_arr) <- result.try(fetch(system))
  use instruction <- result.try(decode(instruction_arr))
  use system <- result.try(execute(system, instruction))

  Ok(system)
}

pub fn run_n(system: System, n: Int) -> Result(System, SystemError) {
  case n {
    0 -> Ok(system)
    _ -> {
      use system <- result.try(run(system))
      run_n(system, n - 1)
    }
  }
}

// LUSTRE / TIRAMISU

pub type Model {
  Model(system: System)
}

pub type Msg {
  Tick(renderer.Tick)
  UserSelectedRom(RomFile)
  RomFileRead(List(Int))
}

pub fn main() -> Nil {
  let assert Ok(_) = tiramisu.register(tiramisu.builtin_extensions())
  let assert Ok(_) =
    lustre.application(init:, update:, view:) |> lustre.start("#app", Nil)
  Nil
}

fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  #(init_model(), effect.none())
}

fn init_model() -> Model {
  Model(system: new_system())
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Tick(tick) -> {
      // Tick runs 60 times per second, so we try to run n instructions in a single
      // tick to get to about 700 instructions per second
      let delta = duration.to_seconds(tick.delta_time)
      let clamped_delta = float.min(delta, 0.1)
      let n = float.round(target_ips *. clamped_delta)

      case run_n(model.system, n) {
        Ok(system) -> #(Model(system:), effect.none())
        // TODO: handle error
        Error(_) -> #(model, effect.none())
      }
    }
    UserSelectedRom(rom_file) -> #(model, read_rom_file(rom_file))
    RomFileRead(bytes) -> {
      case load_rom(model.system, bytes) {
        Ok(system) -> #(Model(system:), effect.none())
        Error(_) -> #(model, effect.none())
      }
    }
  }
}

fn view(model: Model) {
  html.main([], [
    html.div([], [
      html.label([attribute.for("rom")], [html.text("Choose a Chip8 ROM:")]),
      html.input([
        attribute.type_("file"),
        attribute.name("rom"),
        attribute.accept([".ch8", "application/octect-stream"]),
        event.on("change", decode.map(file_decoder(), UserSelectedRom)),
      ]),
    ]),
    tiramisu.renderer(
      "renderer",
      [
        renderer.width(screen_width * 10),
        renderer.height(screen_height * 10),
        renderer.on_tick(Tick),
      ],
      [
        tiramisu.scene("scene", [], [
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
          }),
        ]),
      ],
    ),
  ])
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

@external(javascript, "./file_ffi.mjs", "fileFromOnChange")
fn file_from_on_change(event: dynamic.Dynamic) -> Result(RomFile, RomFile)

@external(javascript, "./file_ffi.mjs", "readBytes")
fn read_bytes(file: RomFile) -> Promise(List(Int))

fn index_to_coords(idx: Int) -> #(Float, Float) {
  let x = { idx % screen_width } |> int.to_float() |> float.add(0.5)
  let y = { idx / screen_width } |> int.to_float() |> float.add(0.5)

  #(x, y)
}

fn pixel_state_to_color(on: Bool) -> Int {
  case on {
    True -> 0xFFFFFF
    False -> 0x000000
  }
}
