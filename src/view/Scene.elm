module View.Scene exposing (renderGameScene, renderNextTetroidScene)

import Grid exposing (Color, Grid, Position, checkGridFallDownCollision, mergeGrids, reColorGrid)
import Html exposing (Html, div, h2, text)
import Html.Attributes exposing (height, style, width)
import List exposing (concat)
import Math.Matrix4 as Mat4 exposing (Mat4)
import Math.Vector3 as Vec3 exposing (Vec3, toRecord, vec3)
import Messages exposing (Msg)
import Model exposing (Model)
import Movement exposing (fallDown, isCollidingWithFloor)
import Tetroids exposing (Tetroid)
import View.UI as UI exposing (myh2)
import WebGL exposing (Mesh, Shader, alpha)
import WebGL.Settings.Blend exposing (add, dstColor, one, oneMinusDstAlpha)
import WebGL.Settings.DepthTest exposing (default)


renderGameScene : Model -> Html Msg
renderGameScene model =
    let
        fullgrid =
            playAreaEntity model
                ++ cellsToWebGLEnteties False
                    model
                    (case model.activeTetroid of
                        Just tetroid ->
                            mergeGrids model.grid tetroid.grid

                        Nothing ->
                            model.grid
                    )
                ++ cellsToWebGLEntetiesAlpha 1
                    False
                    model
                    (case model.activeTetroid of
                        Just tetroid ->
                            previewTetroid model tetroid

                        Nothing ->
                            []
                    )

        options =
            [ WebGL.alpha True, WebGL.antialias, WebGL.depth 1, WebGL.preserveDrawingBuffer, WebGL.clearColor 0 0 0 0 ]

        --dimensions to calc responsiveness
        mainWrapperWidth =
            toFloat model.windowSize.width * 0.8

        leftColumnWidth =
            mainWrapperWidth * 0.8

        gameSceneDimensions =
            fitGameScenee { width = round leftColumnWidth - 20, height = model.windowSize.height - 100 }
    in
    WebGL.toHtmlWith
        options
        [ width (gameSceneDimensions.width - 40)
        , height (gameSceneDimensions.height - 100)
        , style "object-fit" "cover"
        ]
        fullgrid


fitGameScenee : { width : Int, height : Int } -> { width : Int, height : Int }
fitGameScenee canvasSize =
    let
        width =
            200

        height =
            200

        desiredRatio =
            width / height

        canvasratio =
            toFloat canvasSize.width / toFloat canvasSize.height
    in
    if canvasratio > desiredRatio then
        { width = round (width * toFloat canvasSize.height / height), height = canvasSize.height }

    else
        { width = canvasSize.width, height = round (height * toFloat canvasSize.width / width) }


previewTetroid : Model -> Tetroid -> Grid
previewTetroid model activeTetroid =
    let
        -- set down till collision
        downedTetroid =
            bottomOutTetroid model activeTetroid
    in
    reColorGrid (Color 255 10 10) downedTetroid


bottomOutTetroid : Model -> Tetroid -> Grid
bottomOutTetroid model tetroid =
    if checkGridFallDownCollision tetroid.grid model.grid || isCollidingWithFloor tetroid model.dimensions then
        tetroid.grid

    else
        bottomOutTetroid model
            (case model.activeTetroid of
                Just _ ->
                    fallDown tetroid

                Nothing ->
                    tetroid
            )


renderNextTetroidScene : Model -> Html Msg
renderNextTetroidScene model =
    let
        options =
            [ WebGL.alpha True, WebGL.antialias, WebGL.depth 1, WebGL.preserveDrawingBuffer ]

        mainWrapperWidth =
            toFloat model.windowSize.width * 0.9

        rightColumwidth =
            mainWrapperWidth * 0.15
    in
    div []
        [ h2 UI.myh2 [ text "Next Tetroid" ]
        , WebGL.toHtmlWith
            options
            [ width (round rightColumwidth)
            , height (round rightColumwidth)
            , style "margin-top" "-5em"
            ]
            (cellsToWebGLEnteties True
                model
                (case model.upcomingTetroid of
                    Just tetroid ->
                        tetroid.grid

                    Nothing ->
                        []
                )
            )
        ]


type alias Cell =
    { position : Position
    , color : Color
    }


type alias Uniforms =
    { rotation : Mat4
    , perspective : Mat4
    , camera : Mat4
    , shade : Float
    }


uniforms : Bool -> Model -> Uniforms
uniforms isStaticCamera model =
    if isStaticCamera then
        { rotation = Mat4.identity
        , perspective = manipulatePerspective isStaticCamera 8 224 224 model
        , camera = Mat4.makeLookAt (vec3 (model.dimensions.width / 2) 0 (model.dimensions.depth / 2)) (vec3 0 0 0) (vec3 0 -1 0)
        , shade = 0.8
        }

    else
        { rotation = Mat4.identity
        , perspective = manipulatePerspective isStaticCamera 20 1200 1000 model
        , camera = Mat4.makeLookAt (vec3 (model.dimensions.width / 2) 0 (model.dimensions.depth / 2)) (vec3 0 0 0) (vec3 0 -1 0)
        , shade = 0.8
        }



--calc circle


manipulatePerspective : Bool -> Float -> Float -> Float -> Model -> Mat4
manipulatePerspective isStaticCamera zoom width height model =
    if isStaticCamera then
        let
            eye =
                vec3 (0.1 * cos (degrees 95)) 0 (0.1 * sin (degrees 95))
                    |> Vec3.normalize
                    |> Vec3.scale zoom
        in
        Mat4.mul
            (Mat4.makePerspective 40 (width / height) 0.01 1000)
            (Mat4.makeLookAt eye
                (case model.upcomingTetroid of
                    Just tetroid ->
                        vec3 0 -tetroid.center.y 0

                    Nothing ->
                        vec3 0 -1 0
                )
                Vec3.j
            )

    else
        let
            sensitivity =
                0.3

            eye =
                vec3 (0.2 * cos (degrees (model.mousePosition.x * sensitivity))) -(0.25 - model.mousePosition.y / (height * 1.25)) (0.2 * sin (degrees (model.mousePosition.x * sensitivity)))
                    |> Vec3.normalize
                    |> Vec3.scale zoom
        in
        Mat4.mul
            (Mat4.makePerspective 60 (width / height) 0.01 1000)
            (Mat4.makeLookAt eye (vec3 0 -(model.dimensions.height / 2) 0) Vec3.j)



--COORDINATE HELPER
--                  (0,0,6)            (0,6,6)
--               ___________________
--             / |               / |
--   (0,0,0) /__|_______________/__| (6,0,0)
--          |   |              |   |
--          |   |              |   |
--          |   |  (0,13,6)    |   |   (6,13,6)
--          |   | _____________|___|
--          |  /               |  /
-- (0,13,0) |/_________________|/  (0,13,0)
--


cellsToWebGLEnteties : Bool -> Model -> List Cell -> List WebGL.Entity
cellsToWebGLEnteties isStaticCamera model cells =
    case cells of
        [] ->
            []

        [ x ] ->
            [ WebGL.entityWith [ default ]
                vertexShader
                fragmentShader
                (cellToMesh x)
                (uniforms isStaticCamera model)
            ]

        x :: xs ->
            concat
                [ [ WebGL.entityWith [ default ]
                        vertexShader
                        fragmentShader
                        (cellToMesh x)
                        (uniforms isStaticCamera model)
                  ]
                , cellsToWebGLEnteties isStaticCamera model xs
                ]


cellsToWebGLEntetiesAlpha : Float -> Bool -> Model -> List Cell -> List WebGL.Entity
cellsToWebGLEntetiesAlpha alpha isStaticCamera model cells =
    case cells of
        [] ->
            []

        [ x ] ->
            [ WebGL.entityWith [ add dstColor oneMinusDstAlpha, default ]
                vertexShader
                fragmentShader
                (cellToMesh x)
                (uniforms isStaticCamera model)
            ]

        x :: xs ->
            concat
                [ [ WebGL.entityWith [ add dstColor oneMinusDstAlpha, default ]
                        vertexShader
                        fragmentShader
                        (cellToMesh x)
                        (uniforms isStaticCamera model)
                  ]
                , cellsToWebGLEntetiesAlpha alpha isStaticCamera model xs
                ]



-- Mesh


type alias Vertex =
    { color : Vec3
    , position : Vec3
    }


cellToMesh : Cell -> Mesh Vertex
cellToMesh cell =
    let
        cellColor =
            vec3 (toFloat cell.color.r) (toFloat cell.color.g) (toFloat cell.color.b)

        cellPosition =
            toRecord (vec3 cell.position.x cell.position.y cell.position.z)

        --right front top
        rft =
            vec3 (cellPosition.x + 1) (cellPosition.y + 1) cellPosition.z

        -- left front top
        lft =
            vec3 cellPosition.x (cellPosition.y + 1) cellPosition.z

        --left back top
        lbt =
            vec3 cellPosition.x (cellPosition.y + 1) (cellPosition.z + 1)

        --right back top
        rbt =
            vec3 (cellPosition.x + 1) (cellPosition.y + 1) (cellPosition.z + 1)

        --right back bot
        rbb =
            vec3 (cellPosition.x + 1) cellPosition.y (cellPosition.z + 1)

        --right front bot
        rfb =
            vec3 (cellPosition.x + 1) cellPosition.y cellPosition.z

        --left front bot
        lfb =
            vec3 cellPosition.x cellPosition.y cellPosition.z

        -- left back bot
        lbb =
            vec3 cellPosition.x cellPosition.y (cellPosition.z + 1)

        shade1 =
            Vec3.scale 0.9 cellColor

        shade2 =
            Vec3.scale 0.9 shade1
    in
    [ flatFace cellColor rft rfb rbb rbt -- right
    , flatFace shade2 rft rfb lfb lft -- front
    , flatFace shade1 rft lft lbt rbt -- top
    , flatFace shade1 rfb lfb lbb rbb -- bot
    , flatFace cellColor lft lfb lbb lbt --left
    , flatFace shade2 rbt rbb lbb lbt -- back
    ]
        |> List.concat
        |> WebGL.triangles


playAreaEntity : Model -> List WebGL.Entity
playAreaEntity model =
    [ WebGL.entityWith [ add one one ]
        vertexShader
        fragmentShader
        (playareaHulle model)
        (uniforms False model)
    , WebGL.entity
        vertexShader
        fragmentShader
        (playareaBase model)
        (uniforms False model)
    ]


playareaBase : Model -> Mesh Vertex
playareaBase model =
    let
        color =
            vec3 150 150 150

        plateheight =
            1.25

        --right front top
        rft =
            vec3 model.dimensions.width model.dimensions.height 0

        -- left front top
        lft =
            vec3 0 model.dimensions.height 0

        --left back top
        lbt =
            vec3 0 model.dimensions.height model.dimensions.depth

        --right back top
        rbt =
            vec3 model.dimensions.width model.dimensions.height model.dimensions.depth

        --right back bot
        rbb =
            vec3 model.dimensions.width (model.dimensions.height + plateheight) model.dimensions.depth

        --right front bot
        rfb =
            vec3 model.dimensions.width (model.dimensions.height + plateheight) 0

        --left front bot
        lfb =
            vec3 0 (model.dimensions.height + plateheight) 0

        -- left back bot
        lbb =
            vec3 0 (model.dimensions.height + plateheight) model.dimensions.depth

        shade1 =
            Vec3.scale 0.9 color

        shade2 =
            Vec3.scale 0.9 shade1
    in
    [ flatFace color rft rfb rbb rbt -- right
    , flatFace (vec3 255 190 70) rft rfb lfb lft -- front
    , flatFace shade1 rft lft lbt rbt -- top
    , flatFace shade1 rfb lfb lbb rbb -- bot
    , flatFace color lft lfb lbb lbt --left
    , flatFace shade2 rbt rbb lbb lbt -- back
    ]
        |> List.concat
        |> WebGL.triangles


playareaHulle : Model -> Mesh Vertex
playareaHulle model =
    let
        color =
            vec3 175 175 175

        --right front top
        rft =
            vec3 model.dimensions.width 0 0

        -- left front top
        lft =
            vec3 0 0 0

        --left back top
        lbt =
            vec3 0 0 model.dimensions.depth

        --right back top
        rbt =
            vec3 model.dimensions.width 0 model.dimensions.depth

        --right back bot
        rbb =
            vec3 model.dimensions.width model.dimensions.height model.dimensions.depth

        --right front bot
        rfb =
            vec3 model.dimensions.width model.dimensions.height 0

        --left front bot
        lfb =
            vec3 0 model.dimensions.height 0

        -- left back bot
        lbb =
            vec3 0 model.dimensions.height model.dimensions.depth

        shade1 =
            Vec3.scale 0.8 color

        shade2 =
            Vec3.scale 0.9 shade1
    in
    [ flatFace shade1 rft rfb rbb rbt -- right
    , flatFace color rft rfb lfb lft -- front
    , flatFace shade2 rft lft lbt rbt -- top
    , flatFace shade2 rfb lfb lbb rbb -- bot
    , flatFace shade1 lft lfb lbb lbt --left
    , flatFace shade2 rbt rbb lbb lbt -- back
    ]
        |> List.concat
        |> WebGL.triangles


flatFace : Vec3 -> Vec3 -> Vec3 -> Vec3 -> Vec3 -> List ( Vertex, Vertex, Vertex )
flatFace color a b c d =
    let
        vertex position =
            Vertex (Vec3.scale (1 / 255) color) position
    in
    [ ( vertex a, vertex b, vertex c )
    , ( vertex c, vertex d, vertex a )
    ]



-- Shaders


vertexShader : Shader Vertex Uniforms { vcolor : Vec3 }
vertexShader =
    [glsl|
        attribute vec3 position;
        attribute vec3 color;
        uniform mat4 perspective;
        uniform mat4 camera;
        uniform mat4 rotation;
        varying vec3 vcolor;
        void main () {
            gl_Position = perspective * camera * rotation * vec4(position, 1.0);
            vcolor = color;
        }
    |]


fragmentShader : Shader {} Uniforms { vcolor : Vec3 }
fragmentShader =
    [glsl|
        precision mediump float;
        uniform float shade;
        varying vec3 vcolor;
        void main () {
            gl_FragColor = shade * vec4(vcolor, 1.0);
        }
    |]
