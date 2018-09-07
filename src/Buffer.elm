module Buffer
    exposing
        ( Buffer
        , Direction(..)
        , init
        , lines
        , insert
        , replace
        , removeBefore
        , toString
        , between
        , indentFrom
        , indentBetween
        , indentSize
        , deindentFrom
        , deindentBetween
        , groupEnd
        , groupStart
        , groupRange
        , lineEnd
        , nearWordChar
        , clampPosition
        , end
        , undo
        )

import Array.Hamt as Array exposing (Array)
import List.Extra
import String.Extra
import Maybe.Extra
import Position exposing (Position)
import Util.Array
import Editor.History exposing (History, Event(..))


type Buffer
    = Buffer String


indentSize : Int
indentSize =
    2


{-| Create a new buffer from a string
-}
init : String -> Buffer
init content =
    Buffer content


listMapAt : (a -> a) -> Int -> List a -> List a
listMapAt fn index list =
    List.Extra.getAt index list
        |> Maybe.map (\a -> List.Extra.setAt index (fn a) list)
        |> Maybe.withDefault list


indexFromPosition : String -> Position -> Maybe Int
indexFromPosition buffer position =
    -- Doesn't validate columns, only lines
    if position.line == 0 then
        Just position.column
    else
        String.indexes "\n" buffer
            |> List.Extra.getAt (position.line - 1)
            |> Maybe.map (\line -> line + position.column + 1)


undo : Event -> Buffer -> Buffer
undo event (Buffer buffer) =
    case event of
        Insert { cursor, string } ->
            indexFromPosition buffer cursor
                |> Maybe.map
                    (\index ->
                        String.slice 0 index buffer
                            ++ String.dropLeft (index + (String.length string)) buffer
                    )
                |> Maybe.withDefault buffer
                |> Buffer

        Replace { start, removed, inserted } ->
            indexFromPosition buffer start
                |> Maybe.map
                    (\startIndex ->
                        let
                            endIndex =
                                startIndex + String.length inserted
                        in
                            String.slice 0 startIndex buffer
                                ++ removed
                                ++ String.dropLeft endIndex buffer
                    )
                |> Maybe.withDefault buffer
                |> Buffer

        RemoveBefore { cursor, removed } ->
            indexFromPosition buffer cursor
                |> Maybe.map
                    (\index ->
                        String.slice 0 (index - 1) buffer
                            ++ removed
                            ++ String.dropLeft (index - 1) buffer
                    )
                |> Maybe.withDefault buffer
                |> Buffer

        Indent { cursor, moved } ->
            indexFromPosition buffer cursor
                |> Maybe.map
                    (\index ->
                        String.Extra.replaceSlice
                            ""
                            index
                            (index + moved)
                            buffer
                    )
                |> Maybe.withDefault buffer
                |> Buffer

        IndentLines { cursor, selection } ->
            let
                ( updatedBuffer, _, _ ) =
                    deindentBetween cursor selection (Buffer buffer)
            in
                updatedBuffer



-- Deindent { cursor  } ->
--
-- IndentLines { cursor , selection : Position } ->
--
-- DeindentLines { cursor , selection : Position } ->
--
--
-- Indent position _ ->
--
--
-- Deindent position _ ->


nearWordChar : Position -> Buffer -> Bool
nearWordChar position (Buffer buffer) =
    indexFromPosition buffer position
        |> Maybe.andThen
            (\index ->
                let
                    previousChar =
                        stringCharAt (index - 1) buffer

                    currentChar =
                        stringCharAt index buffer
                in
                    Maybe.map isWordChar previousChar
                        |> Maybe.Extra.orElseLazy
                            (\() ->
                                Maybe.map isWordChar currentChar
                            )
            )
        |> Maybe.withDefault False


{-| Insert a string into the buffer.
-}
insert : Position -> String -> ( Buffer, History ) -> ( Buffer, History )
insert position string ( Buffer buffer, history ) =
    indexFromPosition buffer position
        |> Maybe.map
            (\index ->
                ( String.Extra.insertAt string index buffer
                , Editor.History.push
                    (Insert
                        { cursor = position, string = string }
                    )
                    history
                )
            )
        |> Maybe.withDefault ( buffer, history )
        |> Tuple.mapFirst Buffer


replace :
    { cursor : Position, selection : Maybe Position }
    -> Position
    -> Position
    -> String
    -> ( Buffer, History )
    -> ( Buffer, History )
replace { cursor, selection } pos1 pos2 string ( Buffer buffer, history ) =
    let
        ( start, end ) =
            Position.order pos1 pos2
    in
        Maybe.map2
            (\startIndex endIndex ->
                ( String.slice 0 startIndex buffer
                    ++ string
                    ++ String.dropLeft endIndex buffer
                , Editor.History.push
                    (Replace
                        { start = start
                        , end = end
                        , cursor = cursor
                        , selection = selection
                        , removed = String.slice startIndex endIndex buffer
                        , inserted = string
                        }
                    )
                    history
                )
            )
            (indexFromPosition buffer start)
            (indexFromPosition buffer end)
            |> Maybe.withDefault ( buffer, history )
            |> Tuple.mapFirst Buffer


{-| Remove the character before the given position. This is useful because
determining the *previous* valid position is relativly expensive, but it's easy
for the buffer to just use the previous index.
-}
removeBefore : Position -> ( Buffer, History ) -> ( Buffer, History )
removeBefore cursor ( Buffer buffer, history ) =
    indexFromPosition buffer cursor
        |> Maybe.map
            (\index ->
                if index > 0 then
                    ( String.slice 0 (index - 1) buffer
                        ++ String.dropLeft index buffer
                    , Editor.History.push
                        (RemoveBefore
                            { cursor = cursor
                            , removed = String.slice (index - 1) index buffer
                            }
                        )
                        history
                    )
                else
                    ( buffer, history )
            )
        |> Maybe.withDefault ( buffer, history )
        |> Tuple.mapFirst Buffer



-- EXTRACTING CONTENT FROM BUFFERS


lines : Buffer -> List String
lines (Buffer content) =
    String.split "\n" content


toString : Buffer -> String
toString (Buffer buffer) =
    buffer


between : Position -> Position -> Buffer -> String
between pos1 pos2 (Buffer buffer) =
    let
        ( start, end ) =
            Position.order pos1 pos2
    in
        Maybe.map2
            (\startIndex endIndex -> String.slice startIndex endIndex buffer)
            (indexFromPosition buffer start)
            (indexFromPosition buffer end)
            |> Maybe.withDefault ""



-- INDENTING


{-| Indent the given line from the given column. Returns the modified buffer and
the `column + indentedSize`. It accepts a position rather than a line because the
behavior depends on the column. It moves everything after the column to be
aligned with the indent size, content before the column is not moved.
-}
indentFrom : Position -> ( Buffer, History ) -> ( Buffer, Int, History )
indentFrom ({ line, column } as cursor) ( Buffer buffer, history ) =
    indexFromPosition buffer (Position line 0)
        |> Maybe.map
            (\lineStart ->
                let
                    addIndentSize =
                        indentSize
                            - (String.slice lineStart (lineStart + column) buffer
                                |> String.length
                              )
                            % indentSize
                in
                    ( Buffer <|
                        String.slice 0 (lineStart + column) buffer
                            ++ String.repeat addIndentSize " "
                            ++ String.dropLeft (lineStart + column) buffer
                    , column + addIndentSize
                    , Editor.History.push
                        (Indent { cursor = cursor, moved = column + addIndentSize })
                        history
                    )
            )
        |> Maybe.withDefault ( Buffer buffer, column, history )


{-| Indent each line between the given positions (inclusive). All lines will
be indented the full indent size.
-}
indentBetween : Position -> Position -> Buffer -> Buffer
indentBetween pos1 pos2 buffer =
    let
        ( start, end ) =
            Position.order pos1 pos2
    in
        List.range start.line end.line
            |> List.foldl
                (\line ->
                    indentFrom { line = line, column = 0 } >> Tuple.first
                )
                buffer


{-| Deindent the given line. Returns the modified buffer and the column
`minus - deindentedSize`. Unlike `indent`, `deindent` will deindent all the
content in the line, regardless of `position.column`. *Why not just accept a
line then?*, you say. Well, the line might be close to the left, so it won't
deindent the full `indentSize` -- in that case, it's important to know the new
column.
-}
deindentFrom : Position -> Buffer -> ( Buffer, Int )
deindentFrom { line, column } (Buffer buffer) =
    indexFromPosition buffer (Position line 0)
        |> Maybe.map
            (\lineStart ->
                let
                    startChars =
                        String.slice lineStart (lineStart + indentSize) buffer

                    startIndentChars =
                        String.foldl
                            (\char count ->
                                if char == ' ' then
                                    count + 1
                                else
                                    count
                            )
                            0
                            startChars
                in
                    ( Buffer <|
                        String.slice 0 lineStart buffer
                            ++ String.dropLeft (lineStart + startIndentChars) buffer
                    , column - startIndentChars
                    )
            )
        |> Maybe.withDefault ( Buffer buffer, column )


deindentBetween : Position -> Position -> Buffer -> ( Buffer, Int, Int )
deindentBetween pos1 pos2 buffer =
    let
        ( pos1Buffer, pos1Column ) =
            deindentFrom pos1 buffer

        ( pos2Buffer, pos2Column ) =
            deindentFrom pos2 pos1Buffer
    in
        if abs (pos1.line - pos2.line) > 1 then
            let
                ( start, end ) =
                    Position.order pos1 pos2
            in
                ( List.range (start.line + 1) (end.line - 1)
                    |> List.foldl
                        (\line ->
                            deindentFrom { line = line, column = 0 }
                                >> Tuple.first
                        )
                        pos2Buffer
                , pos1Column
                , pos2Column
                )
        else
            ( pos2Buffer, pos1Column, pos2Column )



-- GROUPING


isWhitespace : Char -> Bool
isWhitespace =
    String.fromChar >> String.trim >> (==) ""


isNonWordChar : Char -> Bool
isNonWordChar =
    String.fromChar >> (flip String.contains) "/\\()\"':,.;<>~!@#$%^&*|+=[]{}`?-…"


isWordChar : Char -> Bool
isWordChar char =
    not (isNonWordChar char) && not (isWhitespace char)


type Group
    = None
    | Word
    | NonWord


type Direction
    = Forward
    | Backward


{-| Start at the position and move in the direction using the following rules:

  - Skip consecutive whitespace. Skip a single newline if it follows the whitespace,
    then continue skipping whitespace.
  - If the next character is a newline, stop
  - If the next character is a non-word character, skip consecutive non-word
    characters then stop
  - If the next character is a word character, skip consecutive word characters
    then stop

-}
groupHelp : Direction -> Bool -> String -> Position -> Group -> Position
groupHelp direction consumedNewline string position group =
    let
        parts =
            case direction of
                Forward ->
                    String.uncons string

                Backward ->
                    String.uncons (String.reverse string)
                        |> Maybe.map (Tuple.mapSecond String.reverse)
    in
        case parts of
            Just ( char, rest ) ->
                let
                    nextPosition changeLine =
                        case direction of
                            Forward ->
                                if changeLine then
                                    Position (position.line + 1) 0
                                else
                                    Position.nextColumn position

                            Backward ->
                                if changeLine then
                                    if String.contains "\n" rest then
                                        Position
                                            (position.line - 1)
                                            (String.Extra.rightOfBack "\n" rest
                                                |> String.length
                                            )
                                    else
                                        Position
                                            (position.line - 1)
                                            (String.length rest)
                                else
                                    Position.previousColumn position

                    next nextConsumedNewline =
                        groupHelp
                            direction
                            nextConsumedNewline
                            rest
                            (nextPosition
                                (consumedNewline /= nextConsumedNewline)
                            )
                in
                    case group of
                        None ->
                            if char == '\n' then
                                if consumedNewline then
                                    position
                                else
                                    next True None
                            else if isWhitespace char then
                                next consumedNewline None
                            else if isNonWordChar char then
                                next consumedNewline NonWord
                            else
                                next consumedNewline Word

                        Word ->
                            if not (isWordChar char) then
                                position
                            else
                                next consumedNewline Word

                        NonWord ->
                            if isNonWordChar char then
                                next consumedNewline NonWord
                            else
                                position

            Nothing ->
                position


{-| Start at the position and move right using the following rules:

  - Skip consecutive whitespace. Skip a single newline if it follows the whitespace,
    then continue skipping whitespace.
  - If the next character is a newline, stop
  - If the next character is a non-word character, skip consecutive non-word
    characters then stop
  - If the next character is a word character, skip consecutive word characters
    then stop

-}
groupEnd : Position -> Buffer -> Position
groupEnd position (Buffer buffer) =
    indexFromPosition buffer position
        |> Maybe.map
            (\index -> groupHelp Forward False (String.dropLeft index buffer) position None)
        |> Maybe.withDefault position


{-| Start at the position and move left. Uses the same rules as `groupEnd`.
-}
groupStart : Position -> Buffer -> Position
groupStart position (Buffer buffer) =
    indexFromPosition buffer position
        |> Maybe.map
            (\index ->
                groupHelp
                    Backward
                    False
                    (String.slice 0 index buffer)
                    position
                    None
            )
        |> Maybe.withDefault position


stringCharAt : Int -> String -> Maybe Char
stringCharAt index string =
    String.slice index (index + 1) string
        |> String.uncons
        |> Maybe.map Tuple.first


charsAround : Int -> String -> ( Maybe Char, Maybe Char, Maybe Char )
charsAround index string =
    ( stringCharAt (index - 1) string
    , stringCharAt index string
    , stringCharAt (index + 1) string
    )


tuple3MapAll : (a -> b) -> ( a, a, a ) -> ( b, b, b )
tuple3MapAll fn ( a1, a2, a3 ) =
    ( fn a1, fn a2, fn a3 )


tuple3CharsPred :
    (Char -> Bool)
    -> ( Maybe Char, Maybe Char, Maybe Char )
    -> ( Bool, Bool, Bool )
tuple3CharsPred pred =
    tuple3MapAll (Maybe.map pred >> Maybe.withDefault False)


{-| If the position is in the middle or on the edge of a group, the edges of the
group are returned. Otherwise `Nothing` is returned.
-}
groupRange : Position -> Buffer -> Maybe ( Position, Position )
groupRange position (Buffer buffer) =
    indexFromPosition buffer position
        |> Maybe.andThen
            (\index ->
                let
                    chars =
                        charsAround index buffer

                    range pred =
                        case tuple3CharsPred pred chars of
                            ( True, True, True ) ->
                                Just
                                    ( groupStart position (Buffer buffer)
                                    , groupEnd position (Buffer buffer)
                                    )

                            ( False, True, True ) ->
                                Just
                                    ( position
                                    , groupEnd position (Buffer buffer)
                                    )

                            ( True, True, False ) ->
                                Just
                                    ( groupStart position (Buffer buffer)
                                    , Position.nextColumn position
                                    )

                            ( True, False, _ ) ->
                                Just
                                    ( groupStart position (Buffer buffer)
                                    , position
                                    )

                            ( False, True, False ) ->
                                Just
                                    ( position, Position.nextColumn position )

                            _ ->
                                Nothing
                in
                    range isWordChar
                        |> Maybe.Extra.orElseLazy (\() -> range isNonWordChar)
            )


lineEnd : Int -> Buffer -> Maybe Int
lineEnd line =
    lines >> List.Extra.getAt line >> Maybe.map String.length


{-| Move the position to the closest valid position in the buffer.

If the cursor is:

    - before the first line, move to the first column of the first line
    - after the last line, move to the last column of the last line
    - past the last column of the line, either go to the last column of the line
      or the first column of the next line, depending on the specified direction
    - before the first column of the line, go to the last column of the previous
      line.

-}
clampPosition : Direction -> Buffer -> Position -> Position
clampPosition direction buffer position =
    let
        lines_ =
            lines buffer |> Array.fromList
    in
        if position.line < 0 then
            Position 0 0
        else
            case Array.get position.line lines_ of
                Just line ->
                    if position.column > String.length line then
                        case direction of
                            Forward ->
                                if position.line < (Array.length lines_ - 1) then
                                    Position (position.line + 1) 0
                                else
                                    position

                            Backward ->
                                Position position.line (String.length line)
                    else if position.column < 0 then
                        Array.get (position.line - 1) lines_
                            |> Maybe.map
                                (String.length >> Position (position.line - 1))
                            |> Maybe.withDefault (Position 0 0)
                    else
                        position

                Nothing ->
                    case Util.Array.last lines_ of
                        Just ( line, number ) ->
                            Position number (String.length line)

                        Nothing ->
                            Position 0 0


end : Buffer -> Position
end buffer =
    lines buffer
        |> Array.fromList
        |> Util.Array.last
        |> Maybe.map (\( line, index ) -> Position index (String.length line))
        |> Maybe.withDefault (Position 0 0)
