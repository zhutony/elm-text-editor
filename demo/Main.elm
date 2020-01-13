module Main exposing (Msg(..), main)

import AppText
import Browser
import Browser.Dom as Dom
import Editor exposing (Editor, EditorConfig, EditorMsg)
import Editor.Config exposing (WrapOption(..))
import Editor.Strings
import Editor.Update as E
import Html exposing (Html, button, div, text)
import Html.Attributes as HA exposing (style)
import Html.Events exposing (onClick)
import Json.Encode as E
import Markdown.Elm
import Markdown.Option exposing (..)
import Markdown.Parse as Parse
import Outside
import SingleSlider as Slider
import Strings
import Task exposing (Task)
import Tree exposing (Tree)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- INIT


type Msg
    = NoOp
    | EditorMsg EditorMsg
    | Test
    | FindTreasure
    | GetSpeech
    | GetLongLongLines
    | Reset
    | SliderMsg Slider.Msg
    | Outside Outside.InfoForElm
    | LogErr String
    | SetViewPortForElement (Result Dom.Error ( Dom.Element, Dom.Viewport ))


type alias Model =
    { editor : Editor
    , clipboard : String
    , document : Document
    , sourceText : String
    , ast : Tree Parse.MDBlockWithId
    }


type Document
    = Intro
    | Gettysburg
    | LongLines


init : () -> ( Model, Cmd Msg )
init () =
    ( { editor = Editor.init config Strings.intro
      , clipboard = ""
      , document = Intro
      , sourceText = Strings.intro
      , ast = Parse.toMDBlockTree 0 Extended Strings.intro
      }
    , Cmd.none
    )


config : EditorConfig Msg
config =
    { editorMsg = EditorMsg
    , sliderMsg = SliderMsg
    , width = 450
    , height = 480
    , lineHeight = 16.0
    , showInfoPanel = True
    , wrapParams = { maximumWidth = 55, optimalWidth = 50, stringWidth = String.length }
    , wrapOption = DontWrap
    }



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        EditorMsg editorMsg ->
            let
                ( editor, cmd ) =
                    Editor.update editorMsg model.editor
            in
            case editorMsg of
                E.CopyPasteClipboard ->
                    let
                        clipBoardCmd =
                            if editorMsg == E.CopyPasteClipboard then
                                Outside.sendInfo (Outside.AskForClipBoard E.null)

                            else
                                Cmd.none
                    in
                    ( { model | editor = editor, sourceText = Editor.getSource editor }, Cmd.batch [ clipBoardCmd, Cmd.map EditorMsg cmd ] )

                E.Unload _ ->
                    syncWithEditor model editor cmd

                E.RemoveCharAfter ->
                    syncWithEditor model editor cmd

                E.RemoveCharBefore ->
                    syncWithEditor model editor cmd

                E.Cut ->
                    syncWithEditor model editor cmd

                E.Paste ->
                    syncWithEditor model editor cmd

                E.Undo ->
                    syncWithEditor model editor cmd

                E.Redo ->
                    syncWithEditor model editor cmd

                E.WrapSelection ->
                    syncWithEditor model editor cmd

                E.Clear ->
                    syncWithEditor model editor cmd

                E.WrapAll ->
                    syncWithEditor model editor cmd

                E.SendLine ->
                    ( { model | editor = editor }, syncRenderedText (Editor.lineAtCursor editor) model )

                _ ->
                    ( { model | editor = editor }, Cmd.map EditorMsg cmd )

        SetViewPortForElement result ->
            case result of
                Ok ( element, viewport ) ->
                    ( model, setViewPortForSelectedLine element viewport )

                Err _ ->
                    ( model, Cmd.none )

        Test ->
            load DontWrap Editor.Strings.info model

        GetSpeech ->
            load DoWrap AppText.gettysburgAddress { model | document = Gettysburg }

        GetLongLongLines ->
            load DontWrap AppText.longLines { model | document = LongLines }

        Reset ->
            load DontWrap Strings.intro { model | document = Intro }

        FindTreasure ->
            highlightText "treasure" model

        SliderMsg sliderMsg ->
            let
                ( newEditor, cmd ) =
                    Editor.sliderUpdate sliderMsg model.editor
            in
            ( { model | editor = newEditor }, cmd |> Cmd.map SliderMsg )

        Outside infoForElm ->
            case infoForElm of
                Outside.GotClipboard clipboard ->
                    pasteToEditorClipboard model clipboard

        LogErr _ ->
            ( model, Cmd.none )



-- HELPER FUNCTIONS FOR UPDATE


syncWithEditor : Model -> Editor -> Cmd EditorMsg -> ( Model, Cmd Msg )
syncWithEditor model editor cmd =
    ( { model | editor = editor, sourceText = Editor.getSource editor }, Cmd.map EditorMsg cmd )



-- LR SYNC


syncRenderedText : String -> Model -> Cmd Msg
syncRenderedText str model =
    let
        id =
            case Parse.searchAST str model.ast of
                Nothing ->
                    "???"

                Just id_ ->
                    id_ |> Parse.stringOfId
    in
    setViewportForElement id


setViewportForElement : String -> Cmd Msg
setViewportForElement id =
    Dom.getViewportOf "__rt_scroll__"
        |> Task.andThen (\vp -> getElementWithViewPort vp id)
        |> Task.attempt SetViewPortForElement


getElementWithViewPort : Dom.Viewport -> String -> Task Dom.Error ( Dom.Element, Dom.Viewport )
getElementWithViewPort vp id =
    Dom.getElement id
        |> Task.map (\el -> ( el, vp ))


setViewPortForSelectedLine : Dom.Element -> Dom.Viewport -> Cmd Msg
setViewPortForSelectedLine element viewport =
    let
        y =
            viewport.viewport.y + element.element.y - element.element.height - 100
    in
    Task.attempt (\_ -> NoOp) (Dom.setViewportOf "__rt_scroll__" 0 y)



-- COPY-PASTE


{-| Paste contents of clipboard into Editor
-}
pasteToClipboard : Model -> String -> ( Model, Cmd msg )
pasteToClipboard model str =
    ( { model | editor = Editor.insert (Editor.getWrapOption model.editor) (Editor.getCursor model.editor) str model.editor }, Cmd.none )


pasteToEditorClipboard : Model -> String -> ( Model, Cmd msg )
pasteToEditorClipboard model str =
    let
        cursor =
            Editor.getCursor model.editor

        wrapOption =
            Editor.getWrapOption model.editor

        editor2 =
            Editor.placeInClipboard str model.editor
    in
    ( { model | editor = Editor.insert wrapOption cursor str editor2 }, Cmd.none )


{-| Load text into Editor
-}
load : WrapOption -> String -> Model -> ( Model, Cmd Msg )
load wrapOption str model =
    let
        newEditor =
            Editor.load wrapOption str model.editor
    in
    ( { model | editor = newEditor, sourceText = str }, Cmd.none )


{-| Find str and highlight it
-}
highlightText : String -> Model -> ( Model, Cmd Msg )
highlightText str model =
    let
        newEditor =
            Editor.scrollToString str model.editor
    in
    ( { model | editor = newEditor }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Sub.map SliderMsg <|
            Slider.subscriptions (Editor.slider model.editor)
        , Outside.getInfo Outside LogErr
        ]



-- VIEW


view : Model -> Html Msg
view model =
    div [ HA.style "margin" "60px", HA.class "flex-column", HA.style "width" "1200px" ]
        [ title
        , div
            [ HA.class "flex-row"
            , HA.style "width" "980px"
            , HA.style "align-items" "stretch"
            ]
            [ embeddedEditor model, renderedText model ]
        , footer model
        ]


embeddedEditor : Model -> Html Msg
embeddedEditor model =
    div [ style "width" "500px" ]
        [ Editor.embedded config model.editor ]


renderedText model =
    div
        [ HA.style "flex" "row"
        , HA.style "width" "400px"
        , HA.style "height" "520px"
        , HA.style "border" "solid"
        , HA.style "border-color" "#444"
        , HA.style "border-width" "0.5px"
        , HA.style "overflow-y" "scroll"
        , HA.style "order" "1"
        , HA.style "align-self" "left"
        , HA.style "padding" "12px"
        , HA.attribute "id" "__rt_scroll__"
        ]
        [ Markdown.Elm.toHtml Extended model.sourceText ]


title : Html Msg
title =
    div [ HA.style "font-size" "16px", HA.style "font-style" "bold", HA.style "margin-bottom" "10px" ]
        [ text "A Pure Elm Text Editor" ]


footer : Model -> Html Msg
footer model =
    div
        [ HA.style "font-size" "14px", HA.style "position" "absolute", HA.style "top" "590px", HA.style "left" "80px" ]
        [ div []
            [ Html.a [ HA.href "https://github.com/jxxcarlson/elm-text-editor" ] [ text "Source code (Work in Progress)" ]
            ]
        , div [ HA.style "margin-top" "10px" ] [ text "This app is based on  ", Html.a [ HA.href "https://sidneynemzer.github.io/elm-text-editor/" ] [ text "work of Sydney Nemzer" ] ]
        , div [ HA.style "margin-top" "10px" ] [ text "Press the 'Help' button upper-right for a list of key commands or type ctrl-h to toggle" ]
        , div [ HA.style "margin-top" "10px" ] [ text "ctrl-shift i to toggle info panel." ]
        , div [ HA.style "margin-top" "10px" ] [ resetButton, treasureButton model, speechTextButton, longLinesTextButton ]
        ]



-- BUTTONS


testButton =
    rowButton 80 Test "Info" []


treasureButton model =
    case model.document of
        Intro ->
            rowButton 120 FindTreasure "Find treasure" []

        _ ->
            Html.span [] []


speechTextButton =
    rowButton 160 GetSpeech "Gettysburg Address" []


longLinesTextButton =
    rowButton 160 GetLongLongLines "Long lines" []


resetButton =
    rowButton 80 Reset "Reset" []



-- STYLE --


rowButtonStyle =
    [ style "font-size" "12px"
    , style "border" "none"
    , style "margin-right" "8px"
    , style "float" "left"
    ]


rowButtonLabelStyle width =
    [ style "font-size" "12px"
    , style "background-color" "#666"
    , style "color" "#eee"
    , style "width" (String.fromInt width ++ "px")
    , style "height" "24px"
    , style "border" "none"
    ]


rowButton width msg str attr =
    div (rowButtonStyle ++ attr)
        [ button ([ onClick msg ] ++ rowButtonLabelStyle width) [ text str ] ]
