import gleam/bool
import gleam/dict
import gleam/float
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

pub fn error_to_string(e: Error) -> String {
  case e {
    OutofBoundsError(c) -> "Out of Bounds " <> coord_to_string(c)
    IllegalVectorError(v) -> "Illegal Vector Error " <> vector_to_string(v)
    IllegalMoveError(m) -> "Illegal Move Error " <> move_to_string(m)
    OccupiedTileError(c) -> "Occupied Tile Error " <> coord_to_string(c)
    OccupiedVectorPathError(v) ->
      "Occupied Vector Path Error " <> vector_to_string(v)
    NoAvailableMoves -> "No Available Moves"
  }
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

pub fn int_to_coord_mod(i: Int, m: Int) -> Coordinate {
  C(i % m, i / m)
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

pub fn test_board() -> Board {
  let pieces: List(PiecePosition) = [PP(C(0, 0), black), PP(C(2, 2), white)]
  list.repeat(Free, 9)
  |> list.index_map(fn(_: Tile, i: Int) {
    let initial_coord = int_to_coord_mod(i, 3)

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

pub fn board_to_string(b: Board, width: Int) -> String {
  dict.to_list(b)
  |> list.sort(fn(v1: #(Coordinate, Tile), v2: #(Coordinate, Tile)) {
    case v1, v2 {
      #(coord1, _), #(coord2, _) -> coordinate_compare(coord1, coord2)
    }
  })
  |> list.map(fn(v: #(Coordinate, Tile)) {
    let end = width - 1
    case v {
      #(coord, tile) -> {
        case coord.x {
          x if x == end -> string.concat([tile_to_string(tile), "\n"])
          _ -> tile_to_string(tile)
        }
      }
    }
  })
  |> string.concat
}

pub fn board_to_string_last_move(b: Board, width: Int, move: Move) -> String {
  dict.to_list(b)
  |> list.sort(fn(v1: #(Coordinate, Tile), v2: #(Coordinate, Tile)) {
    case v1, v2 {
      #(coord1, _), #(coord2, _) -> coordinate_compare(coord1, coord2)
    }
  })
  |> list.map(fn(v: #(Coordinate, Tile)) {
    let end = width - 1
    case v {
      #(coord, tile) -> {
        let tile_in_string = case coord {
          c if c == move.end ->
            case tile {
              Piece(c) if c == black -> "🖤"
              Piece(c) if c == white -> "🤍"
              _ -> tile_to_string(tile)
            }
          c if c == move.shoot -> "💥"
          c if c == move.start -> "🔴"
          _ -> tile_to_string(tile)
        }
        case coord.x {
          x if x == end -> string.concat([tile_in_string, "\n"])
          _ -> tile_in_string
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
      Ok(_) -> {
        Error(OccupiedTileError(m.end))
      }
      Error(Nil) -> Error(OutofBoundsError(m.end))
    }
  })
  |> result.then(fn(m: Move) {
    case get_tile(b, m.shoot) {
      Ok(Free) -> Ok(m)
      Ok(_) if m.shoot == m.start -> Ok(m)
      Ok(_) -> {
        Error(OccupiedTileError(m.end))
      }
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
    Error(e) -> {
      Error(e)
    }
  }
}

pub fn empty_path(
  board: Board,
  c: Coordinate,
  dir: Coordinate,
  current: List(Coordinate),
) -> List(Coordinate) {
  let new_c = C(c.x + dir.x, c.y + dir.y)
  case get_tile(board, new_c) {
    Ok(Free) -> empty_path(board, new_c, dir, [new_c, ..current])
    Ok(_) -> current
    Error(_) -> current
  }
}

pub fn possible_vectors_from(board: Board, c: Coordinate) -> List(Vector) {
  [C(1, 0), C(1, 1), C(0, 1), C(-1, 1), C(-1, 0), C(-1, -1), C(0, -1), C(1, -1)]
  |> list.flat_map(fn(dir: Coordinate) { empty_path(board, c, dir, []) })
  |> list.map(fn(end_c: Coordinate) { V(c, end_c) })
}

pub fn possible_moves_from(board: Board, c: Coordinate) -> List(Move) {
  let initial_tile = get_tile(board, c)

  case initial_tile {
    Ok(_) -> {
      possible_vectors_from(board, c)
      |> list.flat_map(fn(v: Vector) {
        [
          M(v.start, v.end, v.start),
          ..list.map(possible_vectors_from(board, v.end), fn(v2: Vector) {
            M(v.start, v.end, v2.end)
          })
        ]
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

pub fn length_empty_path(
  board: Board,
  c: Coordinate,
  dir: Coordinate,
  current: Int,
) -> Int {
  let new_c = C(c.x + dir.x, c.y + dir.y)
  case get_tile(board, new_c) {
    Ok(Free) -> length_empty_path(board, new_c, dir, current + 1)
    Ok(_) -> current
    Error(_) -> current
  }
}

pub fn num_possible_vectors_from(board: Board, c: Coordinate) -> Int {
  [C(1, 0), C(1, 1), C(0, 1), C(-1, 1), C(-1, 0), C(-1, -1), C(0, -1), C(1, -1)]
  |> list.map(fn(dir: Coordinate) { length_empty_path(board, c, dir, 0) })
  |> int.sum
}

pub fn num_possible_moves_from(board: Board, c: Coordinate) -> Int {
  let initial_tile = get_tile(board, c)

  case initial_tile {
    Ok(_) -> {
      possible_vectors_from(board, c)
      |> list.map(fn(v: Vector) { 1 + num_possible_vectors_from(board, v.end) })
      |> int.sum
    }
    Error(Nil) -> 0
  }
}

pub fn num_possible_moves(board: Board, color: Color) -> Int {
  dict.filter(board, fn(_: Coordinate, t: Tile) {
    case t {
      Piece(c) if c == color -> True
      _ -> False
    }
  })
  |> dict.to_list()
  |> list.map(fn(v: #(Coordinate, Tile)) {
    case v {
      #(c, _) -> num_possible_moves_from(board, c)
    }
  })
  |> int.sum
}

pub const max = 100_000

pub const min = -100_000

const win = 2000

const loss = -1000

pub fn evaluate_board_simple(board: Board, color: Color) -> Int {
  case num_possible_moves(board, color) {
    v if v == 0 -> loss
    v -> v - num_possible_moves(board, other_color(color))
  }
}

pub type MCNode {
  N(
    board: Board,
    move: Move,
    value: Int,
    self_value: Int,
    n: Int,
    children: dict.Dict(Int, MCNode),
  )
}

pub fn tree_to_string(depth: Int, node: MCNode) -> String {
  "- "
  <> list.repeat("\t", depth)
  |> string.concat()
  <> "Node("
  <> move_to_string(node.move)
  <> ", value: "
  <> float.to_string(final_eval_node(node))
  <> " ("
  <> int.to_string(node.self_value)
  <> ") "
  <> " with n: "
  <> int.to_string(node.n)
  <> case dict.is_empty(node.children) {
    True -> ""
    False -> "\n"
  }
  <> dict.to_list(node.children)
  |> list.map(fn(v: #(Int, MCNode)) {
    case v {
      #(_, node) -> tree_to_string(depth + 1, node) <> "\n"
    }
  })
  |> string.concat()
}

pub fn eval_node(node: MCNode, parent: MCNode) -> Float {
  int.to_float(node.value)
  /. int.to_float(node.n)
  +. case
    float.square_root(
      case float.square_root(int.to_float(parent.n)) {
        Ok(v) -> v
        Error(Nil) -> 0.0
      }
      /. int.to_float(node.n),
    )
  {
    Ok(v) -> v
    Error(Nil) -> 0.0
  }
}

pub fn final_eval_node(node: MCNode) -> Float {
  int.to_float(node.value) /. int.to_float(node.n)
}

pub fn color_from_depth(depth: Int, initial_color: Color) {
  case int.modulo(depth, 2) {
    Ok(0) -> initial_color
    Ok(_) -> other_color(initial_color)
    Error(_) -> initial_color
  }
}

pub fn multiplier_from_depth(depth: Int) {
  case int.modulo(depth, 2) {
    Ok(0) -> 1
    Ok(_) -> -1
    Error(_) -> 1
  }
}

pub fn explore_tree(
  initial_color: Color,
  depth: Int,
  max_depth: Int,
  current_tree: MCNode,
) -> MCNode {
  let color = color_from_depth(depth, initial_color)

  case dict.is_empty(current_tree.children) {
    True -> {
      case num_possible_moves(current_tree.board, color) {
        v if v == 0 ->
          N(
            current_tree.board,
            current_tree.move,
            multiplier_from_depth(depth) * loss,
            multiplier_from_depth(depth) * loss,
            1,
            dict.new(),
          )
        v -> {
          possible_moves(current_tree.board, color)
          |> list.map(fn(m: Move) {
            task.async(fn() {
              case play_move(current_tree.board, m, color) {
                Ok(new_board) -> {
                  let board_eval =
                    evaluate_board_simple(
                      new_board,
                      color_from_depth(depth, initial_color),
                    )
                    * multiplier_from_depth(depth)
                  Ok(N(new_board, m, board_eval, board_eval, 1, dict.new()))
                }
                Error(_) -> Error(Nil)
              }
            })
          })
          |> list.filter_map(task.await_forever)
          |> fn(children: List(MCNode)) {
            let children_sum: Int =
              children
              |> list.map(fn(n: MCNode) { n.value })
              |> int.sum()

            let children_dict: dict.Dict(Int, MCNode) =
              children
              |> list.index_map(fn(n: MCNode, i: Int) { #(i, n) })
              |> dict.from_list()

            explore_tree(
              initial_color,
              depth,
              max_depth,
              N(
                current_tree.board,
                current_tree.move,
                children_sum + current_tree.value,
                current_tree.self_value,
                list.length(children) + 1,
                children_dict,
              ),
            )
          }
        }
      }
    }
    False -> {
      case depth {
        depth if depth == max_depth -> {
          current_tree
        }
        _ -> {
          let child =
            current_tree.children
            |> dict.to_list
            |> list.map(fn(c: #(Int, MCNode)) {
              case c {
                #(i, c) -> #(i, eval_node(c, current_tree), c)
              }
            })
            |> list.sort(fn(a: #(Int, Float, MCNode), b: #(Int, Float, MCNode)) {
              case a, b {
                #(_, v_a, _), #(_, v_b, _) -> float.compare(v_b, v_a)
                // reverse to get max
              }
            })
            |> list.first()

          case child {
            Ok(#(index, _, child)) -> {
              let new_child =
                explore_tree(initial_color, depth + 1, max_depth, child)

              let new_children =
                dict.insert(current_tree.children, index, new_child)

              let new_children_sum: Int =
                new_children
                |> dict.to_list()
                |> list.map(fn(v: #(Int, MCNode)) {
                  case v {
                    #(_, node) -> node.value
                  }
                })
                |> int.sum()

              let new_children_n: Int =
                new_children
                |> dict.to_list()
                |> list.map(fn(v: #(Int, MCNode)) {
                  case v {
                    #(_, node) -> node.n
                  }
                })
                |> int.sum()

              N(
                current_tree.board,
                current_tree.move,
                new_children_sum + current_tree.self_value,
                current_tree.self_value,
                new_children_n + 1,
                new_children,
              )
            }
            Error(Nil) -> current_tree
          }
        }
      }
    }
  }
}

pub fn mc_eval_(
  color: Color,
  budget: Int,
  max_depth: Int,
  current_tree: MCNode,
) -> MCNode {
  case budget {
    0 -> current_tree
    _ ->
      mc_eval_(
        color,
        budget - 1,
        max_depth,
        explore_tree(color, 0, max_depth, current_tree),
      )
  }
}

pub fn mc_choice(
  board: Board,
  color: Color,
  budget: Int,
  max_depth: Int,
) -> Result(#(Move, Int), Error) {
  let simple_eval = evaluate_board_simple(board, color)
  let node =
    mc_eval_(
      color,
      budget,
      max_depth,
      N(
        board,
        M(C(0, 0), C(0, 0), C(0, 0)),
        simple_eval,
        simple_eval,
        1,
        dict.new(),
      ),
    )

  // io.println(tree_to_string(0, node))

  let child =
    node.children
    |> dict.to_list
    |> list.map(fn(c: #(Int, MCNode)) {
      case c {
        #(i, c) -> #(i, final_eval_node(c), c)
      }
    })
    |> list.sort(fn(a: #(Int, Float, MCNode), b: #(Int, Float, MCNode)) {
      case a, b {
        #(_, v_a, _), #(_, v_b, _) -> float.compare(v_b, v_a)
        // reverse to get max
      }
    })
    |> list.first()

  case child {
    Ok(#(_, value, node)) -> {
      io.println("chose move " <> move_to_string(node.move))
      Ok(#(node.move, float.round(value)))
    }
    Error(Nil) -> Error(NoAvailableMoves)
  }
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

pub fn play_choice_game(
  board: Board,
  color: Color,
  choice: fn(Board, Color) -> Result(#(Move, Int), Error),
) -> Board {
  case num_possible_moves(board, color) {
    0 -> board
    _ -> {
      case choice(board, color) {
        Ok(#(move, i)) -> {
          io.println(
            "Eval for color "
            <> int.to_string(color)
            <> ": "
            <> int.to_string(i),
          )
          case play_move(board, move, color) {
            Ok(board) -> {
              io.println(board_to_string_last_move(board, 10, move))
              play_choice_game(board, other_color(color), choice)
            }
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
  let color = black

  io.println(board_to_string(board, 10))
  io.println(int.to_string(evaluate_board_simple(board, black)))

  play_choice_game(board, color, fn(b: Board, c: Color) {
    mc_choice(b, c, 200, 4)
  })
}
