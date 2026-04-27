import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import iv
import lustre
import lustre/effect.{type Effect}
import tiramisu
import tiramisu/camera
import tiramisu/material
import tiramisu/primitive
import tiramisu/renderer
import tiramisu/scene
import tiramisu/transform
import vec/vec3

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
  ExecuteError
  LoadROMError
}

pub type Model {
  Model(system: System)
}

pub type Msg {
  Tick(renderer.Tick)
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
  Draw(reg_x: Int, reg_y: Int, height: Int)
}

pub fn new_system() -> System {
  let assert Ok(memory) =
    iv.repeat(0, times: 4096)
    |> iv.replace(at: 80, replace: list.length(font), with: iv.from_list(font))

  let assert Ok(screen) = iv.repeat(False, times: 2048) |> iv.set(3, True)

  System(
    pc: 512,
    screen:,
    index_register: 0,
    stack: [],
    delay_timer: 0,
    sound_timer: 0,
    registers: dict.new(),
    memory:,
  )
}

pub fn load_rom(system: System, rom: List(Int)) -> Result(System, SystemError) {
  use memory <- result.try(
    iv.replace(
      system.memory,
      at: 512,
      replace: list.length(rom),
      with: iv.from_list(rom),
    )
    |> result.replace_error(LoadROMError),
  )

  Ok(System(..system, memory:))
}

fn fetch(system: System) -> Result(#(System, BitArray), SystemError) {
  case
    iv.get(system.memory, at: system.pc),
    iv.get(system.memory, at: system.pc + 1)
  {
    Ok(x), Ok(y) -> Ok(#(System(..system, pc: system.pc + 2), <<x, y>>))
    _, _ -> Error(FetchError)
  }
}

fn decode(instruction_arr: BitArray) -> Result(Instruction, SystemError) {
  case instruction_arr {
    <<0:4, 0:4, 14:4, 0:4>> -> Ok(Clear)
    <<1:4, address:12>> -> Ok(Jump(address:))
    <<6:4, reg:4, value>> -> Ok(Set(reg:, value:))
    <<7:4, reg:4, value>> -> Ok(Add(reg:, value:))
    <<10:4, address:12>> -> Ok(SetIdx(address:))
    <<13:4, reg_x:4, reg_y:4, height:4>> -> Ok(Draw(reg_x:, reg_y:, height:))
    _ -> Error(DecodeError)
  }
}

fn execute(
  system: System,
  instruction: Instruction,
) -> Result(System, SystemError) {
  case instruction {
    Clear -> todo
    Jump(address:) -> Ok(System(..system, pc: address))
    Set(reg:, value:) -> {
      let registers = dict.insert(system.registers, reg, value)
      Ok(System(..system, registers:))
    }
    Add(reg:, value:) -> {
      let registers =
        dict.upsert(system.registers, reg, fn(x) {
          case x {
            Some(i) -> i + value
            None -> value
          }
        })
      Ok(System(..system, registers:))
    }
    SetIdx(address:) -> Ok(System(..system, index_register: address))
    Draw(reg_x:, reg_y:, height:) -> todo
  }
}

pub fn run(system: System) -> Result(System, SystemError) {
  use #(system, instruction_arr) <- result.try(fetch(system))
  use instruction <- result.try(decode(instruction_arr))
  use system <- result.try(execute(system, instruction))

  Ok(system)
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

fn update(model: Model, _msg: Msg) -> #(Model, Effect(Msg)) {
  #(model, effect.none())
}

fn view(model: Model) {
  tiramisu.renderer(
    "renderer",
    [renderer.width(640), renderer.height(320), renderer.on_tick(Tick)],
    [
      tiramisu.scene(
        "scene",
        [
          scene.background_color(0x000000),
        ],
        [
          tiramisu.camera(
            "camera",
            [
              camera.active(True),
              camera.orthographic(),
              // camera.left(-320.0),
              // camera.right(320.0),
              // camera.top(160.0),
              // camera.bottom(-160.0),
              // camera.near(0.1),
              // camera.far(100.0),
              transform.position(vec3.Vec3(0.0, 0.0, 20.0)),
            ],
            [],
          ),
          tiramisu.empty("screen", [], {
            let pixel_geom = primitive.box(vec3.Vec3(10.0, 10.0, 1.0))
            iv.index_map(model.system.screen, fn(on, idx) {
              let x = { idx % 64 } * 10 |> int.to_float()
              let y = { idx / 64 } * 10 |> int.to_float()

              let color = case on {
                True -> 0xFFFFFF
                False -> 0x000000
              }

              tiramisu.primitive(
                "pixel-" <> int.to_string(idx),
                [
                  pixel_geom,
                  material.color(color),
                  transform.position(vec3.Vec3(x, y, 0.0)),
                ],
                [],
              )
            })
            |> iv.to_list
          }),
        ],
      ),
    ],
  )
}
