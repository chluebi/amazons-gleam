import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/otp/task
import gleam/result
import gleam/string

type Color =
  Int

pub const black = 0

pub const white = 1

pub type Tile {
  Free
  Arrow
  Piece(color: Color)
}

pub type Coordinate {
  C(x: Int, y: Int)
}

pub type TilePosition {
  TP(coord: Coordinate, t: Tile)
}

pub type PiecePosition {
  PP(coord: Coordinate, color: Color)
}

pub type Vector {
  V(start: Coordinate, end: Coordinate)
}

pub type Move {
  M(start: Coordinate, end: Coordinate, shoot: Coordinate)
}

type Board =
  dict.Dict(Coordinate, Tile)

pub type Error {
  OutofBoundsError(c: Coordinate)
  IllegalVectorError(v: Vector)
  IllegalMoveError(m: Move)
  OccupiedTileError(c: Coordinate)
  OccupiedVectorPathError(v: Vector)
  NoAvailableMoves
}

pub fn other_color(c: Color) -> Color {
  1 - c
}

pub fn coord_to_int(c: Coordinate) -> Int {
  c.y * 10 + c.x
}

pub fn int_to_coord(i: Int) -> Coordinate {
  C(i % 10, i / 10)
}

pub fn coord_to_string(c: Coordinate) -> String {
  "C(" <> int.to_string(c.x) <> ", " <> int.to_string(c.y) <> ")"
}

pub fn vector_to_string(v: Vector) -> String {
  coord_to_string(v.start) <> " -> " <> coord_to_string(v.end)
}

pub fn move_to_string(m: Move) -> String {
  coord_to_string(m.start)
  <> " -> "
  <> coord_to_string(m.end)
  <> " --> "
  <> coord_to_string(m.shoot)
}

pub fn initial_board() -> Board {
  let pieces: List(PiecePosition) = [
    PP(C(3, 0), black),
    PP(C(6, 0), black),
    PP(C(0, 3), black),
    PP(C(9, 3), black),
    PP(C(0, 6), white),
    PP(C(9, 6), white),
    PP(C(3, 9), white),
    PP(C(6, 9), white),
  ]
  list.repeat(Free, 100)
  |> list.index_map(fn(_: Tile, i: Int) {
    let initial_coord = int_to_coord(i)
    let filter_fun = fn(pp: PiecePosition) {
      case pp {
        PP(coord, _) if coord == initial_coord -> True
        _ -> False
      }
    }
    let tile = case list.filter(pieces, filter_fun) {
      [] -> Free
      [PP(_, color)] -> Piece(color)
      _ -> Free
    }
    #(initial_coord, tile)
  })
  |> dict.from_list
}

pub fn tile_to_string(t: Tile) -> String {
  case t {
    Free -> "🟥"
    Arrow -> "🚫"
    Piece(c) if c == white -> "⚪"
    Piece(c) if c == black -> "⚫"
    Piece(c) -> int.to_string(c)
  }
}

pub fn coordinate_compare(coord1: Coordinate, coord2: Coordinate) -> order.Order {
  let comp =
    bool.or(coord1.y < coord2.y, coord1.y == coord2.y && coord1.x < coord2.x)

  case coord1, coord2 {
    coord1, coord2 if coord1.y == coord2.y && coord1.x == coord2.x -> order.Eq
    _, _ if comp -> order.Lt
    _, _ -> order.Gt
  }
}

pub fn board_to_string(b: Board) -> String {
  dict.to_list(b)
  |> list.sort(fn(v1: #(Coordinate, Tile), v2: #(Coordinate, Tile)) {
    case v1, v2 {
      #(coord1, _), #(coord2, _) -> coordinate_compare(coord1, coord2)
    }
  })
  |> list.map(fn(v: #(Coordinate, Tile)) {
    case v {
      #(coord, tile) -> {
        case coord.x {
          9 -> string.concat([tile_to_string(tile), "\n"])
          _ -> tile_to_string(tile)
        }
      }
    }
  })
  |> string.concat
}

pub fn set_tile(b: Board, tp: TilePosition) -> Board {
  dict.insert(b, tp.coord, tp.t)
}

pub fn get_tile(b: Board, searched_coordinate: Coordinate) -> Result(Tile, Nil) {
  dict.get(b, searched_coordinate)
}

pub fn validate_coordinate(c: Coordinate) -> Result(Coordinate, Error) {
  case c {
    C(x, _) if x < 0 -> Error(OutofBoundsError(c))
    C(x, _) if x > 9 -> Error(OutofBoundsError(c))
    C(_, y) if y < 0 -> Error(OutofBoundsError(c))
    C(_, y) if y > 9 -> Error(OutofBoundsError(c))
    _ -> Ok(c)
  }
}

pub fn validate_vector(v: Vector) -> Result(Vector, Error) {
  case validate_coordinate(v.start) {
    Ok(_) -> Ok(v)
    Error(e) -> Error(e)
  }
  |> result.then(fn(v: Vector) {
    case validate_coordinate(v.end) {
      Ok(_) -> Ok(v)
      Error(e) -> Error(e)
    }
  })
  |> result.then(fn(v: Vector) {
    let delta_x = int.absolute_value(v.start.x - v.end.x)
    let delta_y = int.absolute_value(v.start.y - v.end.y)
    case v {
      v if delta_x == 0 && delta_y == 0 -> Error(IllegalVectorError(v))
      v if delta_x == 0 && delta_y != 0 -> Ok(v)
      v if delta_x != 0 && delta_y == 0 -> Ok(v)
      v if delta_x == delta_y -> Ok(v)
      _ -> Error(IllegalVectorError(v))
    }
  })
  |> result.then(fn(v: Vector) { Ok(v) })
}

pub fn vector_path(b: Board, v: Vector) -> Result(List(TilePosition), Error) {
  case validate_vector(v) {
    Ok(_) -> Ok(v)
    Error(e) -> Error(e)
  }
  |> result.then(fn(v: Vector) {
    let delta_x = v.end.x - v.start.x
    let delta_y = v.end.y - v.start.y
    let dir_x = delta_x / int.absolute_value(delta_x)
    let dir_y = delta_y / int.absolute_value(delta_y)
    list.range(
      0,
      int.max(int.absolute_value(delta_x), int.absolute_value(delta_y)),
    )
    |> list.map(fn(i: Int) {
      let x = v.start.x + i * dir_x
      let y = v.start.y + i * dir_y
      case get_tile(b, C(x, y)) {
        Ok(v) -> Ok(TP(C(x, y), v))
        Error(Nil) -> Error(IllegalVectorError(v))
      }
    })
    |> list.try_fold([], fn(acc, el) {
      case el {
        Ok(tp) -> Ok([tp, ..acc])
        Error(e) -> Error(e)
      }
    })
  })
}

pub fn vector_path_check_free(b: Board, v: Vector) -> Result(Nil, Error) {
  let vp = vector_path(b, v)
  case vp {
    Ok(vp) ->
      case
        list.any(vp, fn(tp: TilePosition) {
          case tp.coord {
            c if c == v.start -> False
            c if c == v.end -> False
            _ ->
              case tp.t {
                Free -> False
                _ -> True
              }
          }
        })
      {
        True -> Error(OccupiedVectorPathError(v))
        False -> Ok(Nil)
      }
    Error(e) -> Error(e)
  }
}

pub fn validate_move(
  b: Board,
  m: Move,
  move_color: Color,
) -> Result(Move, Error) {
  case validate_vector(V(m.start, m.end)) {
    Ok(_) -> Ok(m)
    Error(e) -> Error(e)
  }
  |> result.then(fn(m: Move) {
    case validate_vector(V(m.end, m.shoot)) {
      Ok(_) -> Ok(m)
      Error(e) -> Error(e)
    }
  })
  |> result.then(fn(m: Move) {
    case get_tile(b, m.end) {
      Ok(Free) -> Ok(m)
      Ok(_) -> Error(OccupiedTileError(m.end))
      Error(Nil) -> Error(OutofBoundsError(m.end))
    }
  })
  |> result.then(fn(m: Move) {
    case get_tile(b, m.shoot) {
      Ok(Free) -> Ok(m)
      Ok(_) if m.shoot == m.start -> Ok(m)
      Ok(_) -> Error(OccupiedTileError(m.end))
      Error(Nil) -> Error(OutofBoundsError(m.end))
    }
  })
  |> result.then(fn(m: Move) {
    case get_tile(b, m.start) {
      Ok(Piece(color)) if color == move_color -> Ok(m)
      Ok(_) -> Error(OccupiedTileError(m.end))
      Error(Nil) -> Error(OutofBoundsError(m.end))
    }
  })
  |> result.then(fn(m: Move) {
    case vector_path_check_free(b, V(m.start, m.end)) {
      Ok(_) -> Ok(m)
      Error(e) -> Error(e)
    }
  })
  |> result.then(fn(m: Move) {
    case vector_path_check_free(b, V(m.end, m.shoot)) {
      Ok(_) -> Ok(m)
      Error(e) -> Error(e)
    }
  })
  |> result.then(fn(m: Move) { Ok(m) })
}

pub fn play_move(board: Board, move: Move, color: Color) -> Result(Board, Error) {
  case validate_move(board, move, color) {
    Ok(_) ->
      board
      |> set_tile(TP(move.start, Free))
      |> set_tile(TP(move.end, Piece(color)))
      |> set_tile(TP(move.shoot, Arrow))
      |> fn(b: Board) { Ok(b) }
    Error(e) -> Error(e)
  }
}

pub fn possible_vectors_from(board: Board, c: Coordinate) -> List(Vector) {
  let directions = [
    C(1, 0),
    C(1, 1),
    C(0, 1),
    C(-1, 1),
    C(-1, 0),
    C(-1, -1),
    C(0, -1),
    C(1, -1),
  ]
  list.range(1, 10)
  |> list.flat_map(fn(x: Int) {
    list.map(directions, fn(y: Coordinate) { #(x, y) })
  })
  |> list.map(fn(v: #(Int, Coordinate)) {
    case v {
      #(i, dir) -> {
        let vector = V(c, C(c.x + i * dir.x, c.y + i * dir.y))
        #(vector, vector_path_check_free(board, vector))
      }
    }
  })
  |> list.filter_map(fn(v: #(Vector, Result(Nil, Error))) {
    case v {
      #(vector, Ok(Nil)) -> Ok(vector)
      #(_, Error(e)) -> Error(e)
    }
  })
}

pub fn possible_moves_from(board: Board, c: Coordinate) -> List(Move) {
  let initial_tile = get_tile(board, c)

  case initial_tile {
    Ok(initial_tile) -> {
      possible_vectors_from(board, c)
      |> list.flat_map(fn(v: Vector) {
        let new_board =
          board
          |> set_tile(TP(v.end, initial_tile))
          |> set_tile(TP(c, Free))
        list.map(possible_vectors_from(new_board, v.end), fn(v2: Vector) {
          M(v.start, v.end, v2.end)
        })
      })
    }
    Error(Nil) -> []
  }
}

pub fn possible_moves(board: Board, color: Color) -> List(Move) {
  dict.filter(board, fn(_: Coordinate, t: Tile) {
    case t {
      Piece(c) if c == color -> True
      _ -> False
    }
  })
  |> dict.to_list()
  |> list.flat_map(fn(v: #(Coordinate, Tile)) {
    case v {
      #(c, _) -> possible_moves_from(board, c)
    }
  })
  |> list.filter(fn(m: Move) {
    case validate_move(board, m, color) {
      Ok(_) -> True
      Error(_) -> False
    }
  })
}

pub fn play_random_move(board: Board, color: Color) -> Result(Board, Error) {
  let random_move =
    possible_moves(board, color)
    |> list.shuffle()
    |> list.first()

  case random_move {
    Ok(random_move) -> play_move(board, random_move, color)
    Error(Nil) -> Error(NoAvailableMoves)
  }
}

pub fn play_random_game(board: Board, color: Color) -> Board {
  case possible_moves(board, color) {
    [] -> board
    _ ->
      case play_random_move(board, color) {
        Ok(board) -> play_random_game(board, other_color(color))
        Error(_) -> board
      }
  }
}

pub fn evaluate_board(board: Board, color: Color) -> Int {
  list.length(possible_moves(board, color))
  - list.length(possible_moves(board, other_color(color)))
}

pub fn pick_best_move(
  board: Board,
  color: Color,
  eval: fn(Board, Color) -> Int,
) -> Result(#(Move, Int), Nil) {
  possible_moves(board, color)
  |> list.filter_map(fn(m: Move) {
    case play_move(board, m, color) {
      Ok(b) -> Ok(#(m, eval(b, color)))
      Error(_) -> Error(Nil)
    }
  })
  |> list.sort(fn(x1: #(Move, Int), x2: #(Move, Int)) {
    case x1, x2 {
      #(_, i1), #(_, i2) -> int.compare(i2, i1)
      // reverse to get best
    }
  })
  |> list.first()
}

pub fn pick_best_move_parallel(
  board: Board,
  color: Color,
  eval: fn(Board, Color) -> Int,
) -> Result(#(Move, Int), Nil) {
  possible_moves(board, color)
  |> list.map(fn(m: Move) {
    task.async(fn() {
      case play_move(board, m, color) {
        Ok(b) -> Ok(#(m, eval(b, color)))
        Error(_) -> Error(Nil)
      }
    })
  })
  |> list.map(task.await_forever)
  |> list.filter_map(fn(x) { x })
  |> list.sort(fn(x1: #(Move, Int), x2: #(Move, Int)) {
    case x1, x2 {
      #(_, i1), #(_, i2) -> int.compare(i2, i1)
      // reverse to get best
    }
  })
  |> list.first()
}

pub fn play_eval_game(
  board: Board,
  color: Color,
  eval: fn(Board, Color) -> Int,
) -> Board {
  io.println(board_to_string(board))
  case possible_moves(board, color) {
    [] -> board
    _ -> {
      case pick_best_move_parallel(board, color, eval) {
        Ok(#(move, i)) -> {
          io.println(
            "Eval for color "
            <> int.to_string(color)
            <> ": "
            <> int.to_string(i),
          )
          case play_move(board, move, color) {
            Ok(board) -> play_eval_game(board, other_color(color), eval)
            Error(_) -> board
          }
        }
        Error(_) -> board
      }
    }
  }
}

pub fn main() {
  let board = initial_board()
  io.println(board_to_string(board))
  io.println(int.to_string(evaluate_board(board, black)))
  io.println(board_to_string(play_eval_game(board, black, evaluate_board)))
}
