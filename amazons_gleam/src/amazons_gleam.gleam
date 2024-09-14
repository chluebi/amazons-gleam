import gleam/int
import gleam/io
import gleam/list
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
  List(Tile)

pub type Error {
  OutofBoundsError(c: Coordinate)
  IllegalVectorError(v: Vector)
  IllegalMoveError(m: Move)
  OccupiedTileError(c: Coordinate)
  OccupiedVectorPathError(v: Vector)
}

pub fn coord_to_int(c: Coordinate) -> Int {
  c.y * 10 + c.x
}

pub fn int_to_coord(i: Int) -> Coordinate {
  C(i % 10, i / 10)
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
    case list.filter(pieces, filter_fun) {
      [] -> Free
      [PP(_, color)] -> Piece(color)
      _ -> Free
    }
  })
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

pub fn board_to_string(b: Board) -> String {
  list.index_map(b, fn(t: Tile, i: Int) {
    let coord = int_to_coord(i)
    case coord.x {
      9 -> string.concat([tile_to_string(t), "\n"])
      _ -> tile_to_string(t)
    }
  })
  |> string.concat
}

pub fn set_tile(b: Board, tp: TilePosition) -> Board {
  list.index_map(b, fn(t: Tile, i: Int) {
    let initial_coord = int_to_coord(i)
    case tp {
      TP(coord, tile) if coord == initial_coord -> tile
      _ -> t
    }
  })
}

pub fn get_tile(b: Board, searched_coordinate: Coordinate) -> Result(Tile, Nil) {
  list.index_map(b, fn(t: Tile, i: Int) {
    let initial_coord = int_to_coord(i)
    TP(initial_coord, t)
  })
  |> list.find(fn(tp: TilePosition) {
    case tp.coord {
      c if c == searched_coordinate -> True
      _ -> False
    }
  })
  |> result.then(fn(tp: TilePosition) { Ok(tp.t) })
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
        Ok(tp) -> Ok(list.append([tp], acc))
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

pub fn main() {
  io.println(board_to_string(initial_board()))

  io.println(case
    play_move(initial_board(), M(C(3, 0), C(4, 1), C(5, 2)), black)
  {
    Ok(b) -> board_to_string(b)
    Error(e) ->
      case e {
        OutofBoundsError(_) -> "Out of Bounds"
        IllegalVectorError(_) -> "Illegal Vector Error"
        IllegalMoveError(_) -> "Illegal Move Error"
        OccupiedTileError(_) -> "Occupied Tile Error"
        OccupiedVectorPathError(_) -> "Occupied Vector Path Error"
      }
  })
}
