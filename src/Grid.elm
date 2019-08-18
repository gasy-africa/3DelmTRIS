module Grid exposing (Cell, Color, Grid, Position, setPosition)

-- The color of a cell


type alias Color =
    { r : Int, g : Int, b : Int }



-- The position of a cell in 3D space


type alias Position =
    { x : Int, y : Int, z : Int }


setPosition : Int -> Int -> Int -> Position -> Position
setPosition x y z vec =
    { vec | x = x, y = y, z = z }



-- One cell represents a building block of a tetroid


type alias Cell =
    { color : Color
    , position : Position
    }



-- A grid is the composition of many cells


type alias Grid =
    List Cell
