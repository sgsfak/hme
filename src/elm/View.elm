module View exposing (view, modalWinIds)

import AllDict
import Date
import Date.Extra exposing (toFormattedString)
import Dict
import Events exposing (onSelect)
import Graph
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onCheck, onClick, onInput)
import Http
import Msg exposing (..)
import Number.Expanded exposing (..)
import Regex exposing (regex)
import RemoteData
import State exposing (..)
import Utils exposing ((=>), applyUnless, applyWhen)
import ValidateHypermodel
import Rest
import Tuple
import Set


sidebar : State -> Html Msg
sidebar state =
    div [ id "sidebar", class "ui thin left inverted vertical menu sidebar" ]
        [ a [ class "item" ] [ i [ class "home icon" ] [] ]
        , a [ class "item" ] [ i [ class "block layout icon" ] [] ]
        , a [ class "item" ] [ i [ class "block layout icon" ] [] ]
        ]


type alias ButtonConfig a =
    { title : String
    , position : String
    , fitted : Bool
    , icon : String
    , enabled : Bool
    , msg : Maybe a
    }


newBtn : String -> String -> ButtonConfig msg
newBtn title icon =
    { title = title
    , position = "bottom left"
    , fitted = True
    , icon = icon
    , enabled = False
    , msg = Nothing
    }


btnPosition : String -> ButtonConfig msg -> ButtonConfig msg
btnPosition pos c =
    { c | position = pos }


btnIcon : String -> ButtonConfig msg -> ButtonConfig msg
btnIcon iconClass c =
    { c | icon = iconClass }


btnMsg : msg -> ButtonConfig msg -> ButtonConfig msg
btnMsg m c =
    { c | enabled = True, msg = Just m }


btnToButton : ButtonConfig msg -> Html msg
btnToButton =
    btnToButton2 []


btnToButton2 : List (Html msg) -> ButtonConfig msg -> Html msg
btnToButton2 children c =
    let
        position =
            attribute "data-position" c.position

        tooltip =
            attribute "data-tooltip" c.title

        attributes =
            [ position
            , tooltip
            , class "compact ui button"
            ]

        evtsAttrs =
            case c.msg of
                Nothing ->
                    attributes

                Just m ->
                    (onClick m) :: attributes

        cls =
            [ (if c.fitted then
                "fitted"
               else
                ""
              )
            , (if c.enabled then
                ""
               else
                "disabled"
              )
            , c.icon
            , "icon orange button"
            ]
                |> addClasses

        contents =
            i [ class cls ] [] :: children
    in
        button evtsAttrs contents


toolbar : State -> Html Msg
toolbar state =
    let
        notEmptyCanvas =
            State.isEmptyCanvas state

        notEmptyAndHasHypermdodel =
            notEmptyCanvas && not state.needsSaving

        hBtn title icon =
            -- btn title icon hasHypermodel Empty
            newBtn title icon |> btnToButton

        aBtn title icon msg =
            newBtn title icon |> btnMsg msg |> btnToButton

        bBtn title icon msg b =
            newBtn title icon |> applyWhen b (btnMsg msg) |> btnToButton

        cBtn title icon msg =
            bBtn title icon msg notEmptyCanvas

        hasNotifications =
            state.notificationCount > 0

        notif =
            if hasNotifications then
                [ div [ class "floating ui red label" ] [ state.notificationCount |> toString |> text ] ]
            else
                []

        hasRecommendations =
            List.length state.recommendations.asNext + List.length state.recommendations.asPrev > 0

        notif2 =
            if hasRecommendations then
                [ div [ class "floating ui mini red label" ] [ text "*" ] ]
            else
                []
    in
        div [ class "ui grid" ]
            [ div [ class "row" ]
                [ div [ class "left floated menubar" ]
                    [ -- div [ class "compact ui button toggle" ] [ i [ class "sidebar icon" ] [] ] ,
                      div [ class "ui buttons" ]
                        [ aBtn "Select a hypermodel to load.." "folder open" LoadHypermodels
                        , aBtn "Start a new hypermodel.." "file outline" NewHypermodel
                        , bBtn "Save hypermodel.." "save" SaveHypermodel state.needsSaving
                        , bBtn "Reload current hypermodel" "refresh" Refresh state.needsSaving
                        ]
                    , div [ class "ui buttons" ]
                        [ cBtn "Zoom-in" "zoom" (Zoom ZoomIn)
                        , cBtn "Actual Size" "maximize" (Zoom ZoomActualSize)
                        , cBtn "Zoom-Out" "zoom out" (Zoom ZoomOut)
                        ]
                    , div [ class "ui buttons" ]
                        [ aBtn "Select a model from the model repository to add.." "database" LoadModels
                        , newBtn "Recommendations" "idea" |> btnMsg ShowRecommendations |> btnToButton2 notif2
                          -- , hBtn "Add a time-driven iteration" "hourglass half"
                          -- , hBtn "Add a choice construct" "fork"
                          -- , hBtn "Add a block of a branch" "code"
                          -- , hBtn "Add inputs" "sign in"
                          -- , hBtn "Add outputs" "sign out"
                        ]
                    , div [ class "ui buttons" ]
                        [ cBtn "Export xMML description" "file text outline" Export
                        , bBtn "Fill-in inputs and run.." "play" ShowFillInputsDialog notEmptyAndHasHypermdodel
                        , newBtn "Experiments" "History" |> btnMsg ShowExperiments |> btnToButton2 notif
                        ]
                    ]
                , div [ class "ui right floated buttons" ]
                    [ text "Stelios" ]
                ]
            ]


addClasses : List String -> String
addClasses l =
    String.join " " l


modalWinIds : ModalWin -> String
modalWinIds modalWin =
    case modalWin of
        ListModelsWin ->
            "mModalWin"

        ListHypermodelsWin ->
            "hmModalWin"

        SaveHypermodelWin ->
            "savehyperModelWin"

        NodeDetailsWin ->
            "mShowNodeWin"

        ErrorWin ->
            "errorAlertWin"

        InfoWin ->
            "inforAlertWin"

        XMMLWin ->
            "mmlDescriptionWin"

        LaunchExecutionWin ->
            "fillInputsWin"

        ShowExperimentsWin ->
            "showExperimentsWin"

        ShowIssuesWin ->
            "showIssuesWin"

        ShowRecommendationsWin ->
            "showRecommentationsWin"



-- modalWinIds :
--     { listHypermodels : String
--     , listModels : String
--     , saveHypermodel : String
--     , showNodeModel : String
--     , errorAlert : String
--     , mmlDescription : String
--     , fillInputsRunWin : String
--     }
-- modalWinIds =
--     { listHypermodels = "hmModalWin"
--     , listModels = "mModalWin"
--     , showNodeModel = "mShowNodeWin"
--     , saveHypermodel = "savehyperModelWin"
--     , errorAlert = "errorAlertWin"
--     , mmlDescription = "mmlDescriptionWin"
--     , fillInputsRunWin = "fillInputsWin"
--     }
--


viewDate : Date.Date -> String
viewDate dt =
    -- dt |> toFormattedString "EEEE, MMMM d, y 'at' h:mm a"
    dt |> toFormattedString "dd/MM/y hh:mm"


viewHypermodel : List Model -> State.Hypermodel -> Html Msg
viewHypermodel allModels ({ id, title, description, version, created, updated, publishedRepoId } as hypermodel) =
    let
        tags =
            State.tagsForHyperModel allModels hypermodel

        b =
            -- button [ onClick (OpenHypermodel id), class "ui right floated button" ]
            a [ "#" ++ id |> href, class "ui right floated button" ]
                [ i [ class "ui cloud download icon" ] []
                , text "Open"
                ]

        isValid =
            ValidateHypermodel.isValidHypermodel allModels hypermodel

        imgSrc =
            "/hme2/preview?q=99&hmid=" ++ id ++ "&ver=" ++ version

        imgSrcWebp =
            imgSrc ++ "&f=webp"
    in
        div [ class "item" ]
            [ div
                [ class "ui small image"
                , attribute "data-tooltip" id
                , attribute "data-position" "right center"
                ]
                [ Html.node "picture"
                    []
                    [ source
                        [ Html.Attributes.attribute "srcset" imgSrcWebp, type_ "image/webp" ]
                        []
                    , img
                        [ src imgSrc, style [ ( "height", "150px" ), ( "width", "150px" ) ] ]
                        []
                    ]
                ]
            , div [ class "middle aligned content" ]
                [ if isValid then
                    text ""
                  else
                    div [ class "ui tiny ribbon red label" ] [ text "Versioning problems!" ]
                , div [ class "header" ]
                    [ if Utils.isNothing publishedRepoId then
                        text ""
                      else
                        i [ class "star icon" ] []
                    , text title
                    ]
                , div [ class "description" ]
                    [ p []
                        [ text description
                        ]
                    ]
                , div [ class "extra" ]
                    [ b
                    , div [] (List.map (text >> cons >> span [ class "ui tiny teal tag label" ]) tags)
                    , div []
                        [ text "ID: "
                        , a [ "/hme2/h/" ++ id |> href, target "_blank" ] [ text id ]
                        ]
                    , div []
                        [ "Created : "
                            ++ (viewDate created)
                            ++ " Updated : "
                            ++ (viewDate updated)
                            ++ " (version: "
                            ++ version
                            ++ ")"
                            ++ (Maybe.map (\repoId -> " Repository id:" ++ toString repoId) publishedRepoId |> Maybe.withDefault "")
                            |> text
                        ]
                    ]
                ]
            ]


viewInfoAlert : String -> String -> Html Msg
viewInfoAlert title message =
    -- This is a modal window
    let
        modalWin =
            modalWinIds InfoWin
    in
        div [ id modalWin, class "ui modal small" ]
            [ i [ class "ui right floated cancel close icon", onClick (CloseModal InfoWin) ] []
            , div [ class "header" ] [ text title ]
            , div [ class "content" ] [ text message ]
            , div [ class "actions" ]
                [ div [ class "ui primary button", onClick (CloseModal InfoWin) ] [ text "OK" ] ]
            ]


viewErrorAlert : State.AlertError -> Html Msg
viewErrorAlert mError =
    -- This is a modal window
    let
        modalWin =
            modalWinIds ErrorWin

        messageHttp httpError =
            case httpError of
                Http.BadUrl str ->
                    "Bad url : " ++ str

                Http.Timeout ->
                    "Timeout!"

                Http.NetworkError ->
                    "Network error!"

                Http.BadStatus { status } ->
                    case status.code of
                        401 ->
                            "Session expired! You need to log in again :-("

                        412 ->
                            "A new version of the hypermodel exists on server.. You need to re-open it.. and lose your changes :-("

                        _ ->
                            "Server returned bad status code: " ++ status.message ++ " (" ++ toString status.code ++ ")"

                Http.BadPayload payload { status } ->
                    "Server returned bad payload: " ++ payload

        message =
            case mError of
                HttpError httpError ->
                    messageHttp httpError |> text

                OtherError listofErrors ->
                    ul [] (List.map (text >> Utils.list >> li []) listofErrors)

                NoError ->
                    text ""

        title =
            case mError of
                HttpError httpError ->
                    "Server Error"

                OtherError listofErrors ->
                    "Hypermodel Load problem: hypermodel uses older versions of models"

                _ ->
                    ""
    in
        div [ id modalWin, class "ui modal small" ]
            [ i [ class "ui right floated cancel close icon", onClick (CloseModal ErrorWin) ] []
            , div [ class "header" ] [ text title ]
            , div [ class "content" ] [ message ]
            , div [ class "actions" ]
                [ div [ class "ui primary button", onClick (CloseModal ErrorWin) ] [ text "OK" ] ]
            ]


styleParam : Bool -> State.ModelInOutput -> List (Html.Attribute msg)
styleParam isInput { description, isDynamic } =
    [ attribute "data-tooltip"
        (if String.isEmpty description then
            " -- empty -- "
         else
            description
        )
    , attribute "data-position" "top left"
    , attribute "data-variation" "miny"
    , style
        [ ( "color"
          , if isDynamic then
                "#928A97"
            else if isInput then
                "#16A085"
            else
                "#ff7e5d"
          )
        ]
    ]


valueRangeToString : State.ValueRange -> String
valueRangeToString ( lowExp, upExp ) =
    let
        isFinite exp =
            case exp of
                Finite a ->
                    True

                _ ->
                    False

        e2s : Expanded number -> String
        e2s exp =
            case exp of
                Finite a ->
                    toString a

                PosInfinity ->
                    "+∞"

                _ ->
                    "-∞"
    in
        (if isFinite lowExp then
            "["
         else
            "("
        )
            ++ (e2s lowExp)
            ++ " - "
            ++ (e2s upExp)
            ++ (if isFinite upExp then
                    "]"
                else
                    ")"
               )


viewNodeDetails : State -> Html Msg
viewNodeDetails state =
    let
        modalWin =
            modalWinIds NodeDetailsWin

        connectedParamsOf : Bool -> Graph.NodeId -> List String
        connectedParamsOf inputOnly nodeId =
            Graph.connectionsOfNode nodeId state.wip.graph
                |> List.map
                    (\conn ->
                        if inputOnly && conn.sourceId == nodeId then
                            conn.sourcePort
                        else
                            conn.targetPort
                    )

        connParams inputOnly =
            state.selectedNode |> Maybe.map (connectedParamsOf inputOnly) |> Maybe.withDefault []

        viewParam isInput ({ name, dataType, description, isDynamic, units, range, defaultValue, meaningUri, unitsUri } as param) =
            let
                connectedParams =
                    connParams isInput

                ontoTermToText ontologyMap maybeUri =
                    maybeUri
                        |> Maybe.map (ontoTermToHtml ontologyMap)
                        |> Maybe.withDefault (text "")
            in
                li
                    (styleParam isInput param)
                    [ code [] [ text name ]
                    , text " : "
                    , code [] [ text dataType ]
                    , if String.isEmpty units then
                        text ""
                      else
                        span [] [ text " in ", code [] [ text units ] ]
                    , case range of
                        Nothing ->
                            text ""

                        Just vr ->
                            valueRangeToString vr |> (++) " Range: " |> text
                    , case defaultValue of
                        Just defVal ->
                            if isInput && defVal /= "" then
                                span [] [ text " Def. ", code [] [ text defVal ] ]
                            else
                                text ""

                        _ ->
                            text ""
                    , ontoTermToText State.meaningOntologyMap meaningUri
                    , ontoTermToText State.unitsOntologyMap unitsUri
                    , if List.member name connectedParams then
                        i [ class "icon checkmark box" ] []
                      else
                        text ""
                    ]

        viewInputParam =
            viewParam True

        viewOutputParam =
            viewParam False

        h : State.Model -> Html Msg
        h ({ id, title, description, inPorts, outPorts, isHypermodel } as m) =
            div [ Html.Attributes.id modalWin, class "ui modal" ]
                [ i [ class "ui right floated  cancel close icon", onClick (CloseModal NodeDetailsWin) ] []
                , div [ class "header" ] [ title ++ " (" ++ (toString id) ++ ")" |> text ]
                , div [ class "content", style [ ( "height", "400px" ), ( "overflow-x", "scroll" ) ] ]
                    [ div [ class "ui attached message" ]
                        [ if isHypermodel then
                            a [ class "ui red ribbon label" ] [ text "Hypermodel" ]
                          else
                            text ""
                        , text description
                        , List.map (text >> cons >> span [ class "ui tiny teal tag label" ]) (State.tagsForModel m) |> div []
                        ]
                    , div [ class "ui styled fluid accordion" ]
                        [ div [ class "title" ]
                            [ i [ class "dropdown icon" ] [], text "Inputs" ]
                        , div [ class "content" ]
                            [ ul [ class "transition hidden" ] (List.map viewInputParam inPorts)
                            ]
                        , div [ class "title" ]
                            [ i [ class "dropdown icon" ] [], text "Outputs" ]
                        , div [ class "content" ]
                            [ ul [ class "transition hidden" ] (List.map viewOutputParam outPorts)
                            ]
                        ]
                    ]
                , div [ class "actions" ]
                    [ div [ class "ui primary button", onClick (CloseModal NodeDetailsWin) ] [ text "OK" ] ]
                ]
    in
        findSelectedModel state |> Maybe.map h |> Maybe.withDefault (text "")


ontoTermToHtml : Dict.Dict String String -> String -> Html msg
ontoTermToHtml ontologyMap uri =
    span [ class "ui label" ] [ abbr [ title uri ] [ Dict.get uri ontologyMap |> Maybe.withDefault uri |> text ] ]


viewFillInputs : List ( Graph.NodeId, Model ) -> AllDict.AllDict Graph.NodeId (List ModelInOutput) Int -> HypermodelExecutionInput -> Html Msg
viewFillInputs models freeInputsOfHypermodel inputs =
    let
        modalWin =
            modalWinIds LaunchExecutionWin

        viewModel : Graph.NodeId -> Model -> List ModelInOutput -> ModelExecutionInputs -> List (Html Msg)
        viewModel nodeId { title } freeInputs modelInputs =
            let
                title_ =
                    title ++ " (" ++ (Graph.ordNodeId nodeId |> toString) ++ ")"

                buttons =
                    [ button
                        [ class "ui tiny orange button"
                        , onClick (DoFillDefaultInputsOf nodeId |> ExecutionInputs)
                        ]
                        [ text "Fill default values"
                        ]
                    , button
                        [ class "ui tiny yellow button"
                        , onClick (ClearInputsOf nodeId |> ExecutionInputs)
                        ]
                        [ text "Clear values"
                        ]
                    , div [ class "ui checkbox" ]
                        [ input [ type_ "checkbox", onCheck (UseCaching nodeId >> ExecutionInputs) ] []
                        , label [] [ text "Use caching" ]
                        ]
                    ]

                fields =
                    List.foldr (\x acc -> (viewInputParam nodeId modelInputs x) :: acc) buttons freeInputs
            in
                [ div [ class "title" ] [ i [ class "dropdown icon" ] [], title_ |> text ]
                , div [ class "content transition hidden" ]
                    [ div [ class "ui small form" ] fields
                    ]
                ]

        viewInputParam : Graph.NodeId -> Dict.Dict String String -> State.ModelInOutput -> Html Msg
        viewInputParam nodeId filledValues ({ name, description, dataType, defaultValue, units, isDynamic } as modelInput) =
            let
                filledValue =
                    Dict.get name filledValues

                dv =
                    defaultValue |> Maybe.withDefault ""

                hasNonDefValue =
                    Maybe.map ((/=) dv) filledValue |> Maybe.withDefault False

                isScalar =
                    dataType == "number" || dataType == "float" || dataType == "double"

                -- a regexp pattern
                -- for the scientific notation of numbers
                -- (see https://stackoverflow.com/questions/638565/parsing-scientific-notation-sensibly)
                numberRegexp =
                    Regex.regex "-?(?:0|[1-9]\\d*)(?:\\.\\d*)?(?:[eE][+\\-]?\\d+)?"

                matchesRegexp regex str =
                    Regex.replace (Regex.AtMost 1) regex (\_ -> "") str |> String.isEmpty

                error =
                    isDynamic || isScalar && (filledValue |> Maybe.map (not << matchesRegexp numberRegexp) |> Maybe.withDefault False)
            in
                div
                    [ classList
                        [ "inline" => True
                        , "field" => True
                        , "required" => (defaultValue == Nothing)
                        , "disabled" => isDynamic
                        , "error" => error
                        ]
                    , attribute
                        "data-tooltip"
                        (if String.isEmpty description then
                            " -- empty -- "
                         else
                            description
                        )
                    , attribute "data-position" "top left"
                    , attribute "data-variation" "miny"
                    ]
                    [ label [] [ text name ]
                    , mkInput nodeId name dv dataType filledValue
                    , if isScalar && not (String.isEmpty units) then
                        code [] [ " " ++ units |> text ]
                      else
                        text ""
                    , if hasNonDefValue then
                        button
                            [ class "ui tiny circular icon button"
                            , onClick (FilledInput nodeId name dv |> ExecutionInputs)
                            ]
                            [ i [ class "reply icon" ] [] ]
                      else
                        text ""
                    ]

        mkInput nodeId name defaultValue dataType maybeValue =
            let
                vv =
                    Maybe.withDefault "" maybeValue

                size_ =
                    if dataType == "file" || dataType == "string" then
                        70
                    else
                        10

                attrs =
                    [ placeholder defaultValue
                    , type_ "text"
                    , size size_
                    , onInput (FilledInput nodeId name >> ExecutionInputs)
                    , value vv
                    ]
            in
                Html.input attrs []

        doAll : ( Graph.NodeId, Model ) -> List (Html Msg)
        doAll ( nodeId, model ) =
            let
                freeInputs =
                    AllDict.get nodeId freeInputsOfHypermodel |> Maybe.withDefault []
            in
                if List.isEmpty freeInputs then
                    []
                else
                    AllDict.get nodeId inputs |> Maybe.withDefault Dict.empty |> viewModel nodeId model freeInputs
    in
        div [ id modalWin, class "ui modal" ]
            [ i [ class "ui right floated  cancel close icon", onClick (CloseModal LaunchExecutionWin) ] []
            , div [ class "header" ] [ text "Execution Inputs (only models with non-connected inputs are shown)" ]
            , div [ class "content", style [ ( "height", "400px" ), ( "overflow-x", "scroll" ) ] ]
                [ div [ class "ui styled fluid accordion" ] (List.concatMap doAll models)
                ]
            , div [ class "actions" ]
                [ div
                    [ class "ui orange button"
                    , onClick (ExecutionInputs DoFillDefaultInputs)
                    ]
                    [ text "Fill All default values" ]
                , div
                    [ class "ui yellow button"
                    , onClick (ExecutionInputs ClearAllInputs)
                    ]
                    [ text "Clear all values" ]
                , div [ class "ui primary positive button", onClick PublishHypermodel ] [ text "Run!" ]
                , div [ class "ui button", onClick (CloseModal LaunchExecutionWin) ] [ text "Cancel" ]
                ]
            ]


viewConnectionValidityIssues : State.State -> Html Msg
viewConnectionValidityIssues { connectionsValidity } =
    let
        modalWin =
            modalWinIds ShowIssuesWin

        e : State.ConnectionValidityError -> Html Msg
        e err =
            case err of
                State.ConnectionMeaningMatchError m1 m2 ->
                    li []
                        [ text "Different meanings: "
                        , (ontoTermToHtml State.meaningOntologyMap m1)
                        , text " versus "
                        , (ontoTermToHtml State.meaningOntologyMap m2)
                        ]

                State.ConnectionUnitsMatchError m1 m2 ->
                    li []
                        [ text "Different units: "
                        , (ontoTermToHtml State.unitsOntologyMap m1)
                        , text " versus "
                        , (ontoTermToHtml State.unitsOntologyMap m2)
                        ]

                State.ConnectionRangeMatchError v1 v2 ->
                    li []
                        [ text "No intersection in value ranges : "
                        , valueRangeToString v1 |> text
                        , text " versus "
                        , valueRangeToString v2 |> text
                        ]
    in
        div [ id modalWin, class "ui modal" ]
            [ i [ class "ui right floated  cancel close icon", onClick (CloseModal ShowIssuesWin) ] []
            , h1 [ class "centered header ui" ] [ text "Connection validity checks" ]
            , div [ class "content", style [ ( "height", "300px" ), ( "overflow-x", "scroll" ) ] ]
                [ div [ class "ui fluid" ]
                    [ case connectionsValidity of
                        State.ConnectionInvalid (ConnectionValidityInfo { source, target }) lst ->
                            div []
                                [ h2 [ class "red block ui header" ] [ text "Connection is invalid!" ]
                                , p []
                                    [ text "The connection between '"
                                    , code (styleParam False source) [ text source.name ]
                                    , text "' and '"
                                    , code (styleParam True target) [ text target.name ]
                                    , text "' is invalid:"
                                    ]
                                , ul [] (List.map e lst)
                                ]

                        _ ->
                            text ""
                    ]
                ]
            , div [ class "actions" ]
                [ div [ class "ui button", onClick (CloseModal ShowIssuesWin) ] [ text "OK" ]
                ]
            ]


viewRecommendations : State.State -> Html Msg
viewRecommendations ({ recommendations } as state) =
    let
        modalWin =
            modalWinIds ShowRecommendationsWin

        e : Bool -> List State.ModelParamIndexEntry -> State.Model -> Html Msg
        e isPrev lst model =
            let
                gg param =
                    code (styleParam False param) [ text param.name ]

                b =
                    button [ class "mini button compact ui", onClick (AddModel model) ]
                        [ i [ class "button fitted icon orange plus" ] []
                        ]

                pp : State.ModelInOutput -> Html Msg
                pp param =
                    Maybe.withDefault "" param.meaningUri |> ontoTermToHtml State.meaningOntologyMap

                isUsed =
                    State.modelIsUsed state model

                a : List (Html msg)
                a =
                    List.filterMap (.param >> .meaningUri) lst
                        |> Set.fromList
                        |> Set.toList
                        |> List.map (ontoTermToHtml State.meaningOntologyMap)
            in
                li []
                    [ text "Model "
                    , code [] [ text model.title, " (" ++ toString model.id ++ ")" |> text ]
                    , if isPrev then
                        text " provides: "
                      else
                        text " accepts: "
                    , span [] a
                    , text " "
                    , if isUsed then
                        text ""
                      else
                        b
                    ]

        h : Bool -> List State.ModelParamIndexEntry -> List (Html Msg)
        h isPrev lst =
            let
                groups : List ( String, List State.ModelParamIndexEntry )
                groups =
                    List.map (Utils.indexedPair .modelUuid) lst |> Utils.groupListToDict |> Dict.toList
            in
                groups
                    |> List.filterMap (Tuple.mapFirst (State.findModel state) >> Utils.liftMaybeToTuple2)
                    |> List.map (\( model, entries ) -> e isPrev entries model)

        content =
            let
                hasPrev =
                    List.length recommendations.asPrev > 0

                hasNext =
                    List.length recommendations.asNext > 0
            in
                [ h3 [ class "ui header" ] [ text "The following models can be connected to the selected one:" ]
                , ul []
                    [ if hasPrev then
                        li []
                            [ h4 [ class "ui header" ] [ text "As a previous step" ]
                            , ul [] (h True recommendations.asPrev)
                            ]
                      else
                        text ""
                    , if hasNext then
                        li []
                            [ h4 [ class "ui header" ] [ text "As a next step" ]
                            , ul [] (h False recommendations.asNext)
                            ]
                      else
                        text ""
                    ]
                ]

        allModels =
            RemoteData.withDefault [] state.allModels

        currentPerps =
            State.modelsOfHypermodel allModels state.wip
                |> List.filterMap (.annotations >> Dict.get perspective4.uri)
                |> List.concat
                |> Set.fromList

        addedPersps =
            Set.toList currentPerps

        missingPersps =
            Set.diff State.chicHypermodellingBestPractice currentPerps |> Set.toList

        perspVal toAdd =
            let
                m =
                    .values State.perspective4 |> Dict.fromList
            in
                \uri ->
                    Dict.get uri m
                        |> Maybe.map
                            (code [ classList [ "label ui" => True, "teal" => toAdd ] ]
                                << cons
                                << text
                            )

        bb =
            if (List.length recommendations.asNext) + (List.length recommendations.asPrev) > 0 then
                content
            else if List.length missingPersps + List.length addedPersps > 0 then
                [ h2 [ class "ui center aligned icon header" ]
                    [ i [ class "circular trophy icon" ] []
                    , text "CHIC Best practices"
                    ]
                , if List.length addedPersps > 0 then
                    div [ class "ui vertical segment" ]
                        [ p [] (text "You have added models of the following biomechanisms: " :: (List.filterMap (perspVal False) addedPersps))
                        ]
                  else
                    text ""
                , if List.length missingPersps > 0 then
                    div [ class "ui vertical segment" ]
                        [ p [] (text "You may also consider adding models of these biomechanisms: " :: (List.filterMap (perspVal True) missingPersps)) ]
                  else
                    text "Well done!"
                ]
            else
                [ h3 [ class "centered header block ui" ] [ text "Sorry, nothing to propose at this point.." ] ]
    in
        div [ id modalWin, class "ui modal" ]
            [ i [ class "ui right floated  cancel close icon", onClick (CloseModal ShowRecommendationsWin) ] []
            , h1 [ class "centered header ui" ] [ text "Recommendations" ]
            , div [ class "content", style [ ( "height", "300px" ), ( "overflow-x", "scroll" ) ] ]
                [ div [ class "ui fluid" ]
                    bb
                ]
            , div [ class "actions" ]
                [ div [ class "ui button", onClick (CloseModal ShowRecommendationsWin) ] [ text "OK" ]
                ]
            ]


viewHypermodels : List State.Model -> List State.Hypermodel -> Html Msg
viewHypermodels allModels allHypermodels =
    -- This is a modal window
    let
        sortedHypermodels =
            List.sortBy (.updated >> Date.toTime >> negate) allHypermodels

        modalWin =
            modalWinIds ListHypermodelsWin
    in
        div [ id modalWin, class "ui modal long scrolling" ]
            [ i [ class "ui right floated  cancel close icon", onClick (CloseModal ListHypermodelsWin) ] []
            , div [ class "header" ] [ text "Available Hypermodels" ]
            , div [ class "content", style [ ( "height", "400px" ), ( "overflow-x", "scroll" ) ] ]
                [ div [ class "ui items" ]
                    (List.map (viewHypermodel allModels) sortedHypermodels)
                ]
            , div [ class "actions" ]
                [ div [ class "ui cancel button", onClick (CloseModal ListHypermodelsWin) ] [ text "Cancel" ] ]
            ]


viewExperiments : Dict.Dict State.ExperimentUuid State.ExperimentStatus -> List State.Experiment -> Html Msg
viewExperiments hotExperimentUuids experiments =
    -- This is a modal window
    let
        viewExperiment { uuid, hypermodelId, title, experimentRepoId, status, version } =
            let
                name =
                    title ++ " (ver. " ++ (toString version) ++ ")"

                updatedStatus =
                    Dict.get uuid hotExperimentUuids |> Maybe.withDefault status

                isRunning =
                    updatedStatus == State.RUNNING

                failed =
                    updatedStatus == State.FINISHED_FAIL

                success =
                    updatedStatus == State.FINISHED_OK

                hasFinished =
                    failed || success

                isHot =
                    Dict.member uuid hotExperimentUuids

                stylesForHot =
                    if isHot then
                        [ ( "font-weight", "bolder" ) ]
                    else
                        []

                styles =
                    if isRunning then
                        ( "font-style", "italic" ) :: stylesForHot
                    else if failed then
                        ( "color", "red" ) :: stylesForHot
                    else if success then
                        ( "color", "green" ) :: stylesForHot
                    else
                        stylesForHot

                b =
                    if hasFinished then
                        a
                            [ class "compact ui button"
                            , attribute "data-tooltip" "Download"
                            , href (Rest.downloadExperimentUri uuid)
                            ]
                            [ i [ class "fitted Download icon orange button" ] []
                            ]
                    else
                        i [ class "notched circle loading icon" ] []

                statusText =
                    case updatedStatus of
                        State.FINISHED_OK ->
                            "Finished"

                        State.FINISHED_FAIL ->
                            "Failed"

                        State.RUNNING ->
                            "Running"

                        State.NOT_STARTED ->
                            "Not started"
            in
                tr
                    [ classList [ ( "negative", failed ), ( "positive", success ) ]
                    , Html.Attributes.id ("exp-" ++ uuid)
                    ]
                    [ td [ style styles ] [ toString experimentRepoId |> text ]
                    , td [ style styles ] [ text name ]
                    , td [ style styles ] [ statusText |> text ]
                    , td [ class "center aligned" ] [ b ]
                    ]

        modalWin =
            modalWinIds ShowExperimentsWin
    in
        div [ id modalWin, class "ui modal long scrolling" ]
            [ i [ class "ui right floated  cancel close icon", onClick (CloseModal ShowExperimentsWin) ] []
            , div [ class "header" ] [ text "Experiments" ]
            , div [ class "content", style [ ( "height", "400px" ), ( "overflow-x", "scroll" ) ] ]
                [ table [ class "ui small selectable celled striped padded table" ]
                    [ thead [] [ tr [] [ th [] [ text "#" ], th [] [ text "Hypermodel" ], th [] [ text "Status" ], th [] [ text "" ] ] ]
                    , tbody [] (List.map viewExperiment experiments)
                    ]
                ]
            , div [ class "actions" ]
                [ div [ class "ui primary button", onClick (CloseModal ShowExperimentsWin) ] [ text "OK" ] ]
            ]


viewExportMML : String -> Html Msg
viewExportMML mml =
    let
        modalWin =
            modalWinIds XMMLWin
    in
        div [ id modalWin, class "ui modal long scrolling" ]
            [ i [ class "ui right floated  cancel close icon", onClick (CloseModal XMMLWin) ] []
            , div [ class "header" ] [ text "xMML Description" ]
            , div [ class "content", style [ ( "height", "400px" ), ( "overflow-x", "scroll" ) ] ]
                [ div [ class "ui inverted segment" ]
                    [ pre
                        [ class "lang-xml"
                          --, style [ ( "background-color", "#EDF2F6" ) ]
                        ]
                        [ code [ class "xml" ] [ text mml ] ]
                    ]
                ]
            , div [ class "actions" ]
                [ div [ class "ui primary button", onClick (CloseModal XMMLWin) ] [ text "OK" ] ]
            ]


cons : a -> List a
cons a =
    [ a ]


viewModel : State.State -> State.Model -> Html Msg
viewModel state m =
    let
        isUsed =
            State.modelIsUsed state m

        isStronglyCoupled =
            State.modelIsDynamic m

        styles =
            (if isStronglyCoupled then
                [ ( "font-weight", "bold" ), ( "font-style", "italic" ) ]
             else
                []
            )
                ++ (if isUsed then
                        [ ( "text-decoration", "line-through" ) ]
                    else
                        []
                   )

        b =
            newBtn ("Add " ++ m.title) "Plus" |> btnPosition "left center" |> btnMsg (AddModel m) |> btnToButton
    in
        tr
            []
            [ td [ style styles, classList [ ( "disabled", isUsed ), ( "collapsing", True ) ] ] [ toString m.id |> text ]
            , td [ style styles, classList [ ( "disabled", isUsed ), ( "collapsing", True ) ] ] [ text m.title ]
            , td [ style styles, classList [ ( "disabled", isUsed ) ] ]
                [ if m.isHypermodel then
                    a [ class "ui red ribbon label" ] [ text "Hypermodel" ]
                  else
                    text ""
                , text m.description
                , State.tagsForModel m |> List.map (text >> cons >> span [ class "ui tiny teal tag label" ]) |> div []
                ]
            , td [ style styles, classList [ ( "disabled", isUsed ), ( "collapsing", True ) ] ] [ toString m.usage |> text ]
            , td [ class "collapsing" ] [ b ]
            ]


viewPerspectiveSelect : Perspective -> Html Msg
viewPerspectiveSelect { index, name, uri, values } =
    let
        title =
            "Perspective " ++ (toString index)

        msg : Maybe String -> Msg
        msg m =
            Msg.ModelSearchPerspective { uri = uri, value = m } |> ModelSearch
    in
        div [ class "inline field", attribute "data-tooltip" title ]
            [ label [] [ text name ]
            , select [ class "ui dropdown", onSelect msg ]
                (option [ value "", selected True ] [ text "--" ]
                    :: List.map
                        (\( u, v ) ->
                            option [ value u ] [ text v ]
                        )
                        values
                )
            ]


viewModels : State.State -> State.ModelSearchState -> Html Msg
viewModels state modelSearch =
    -- This is a modal window
    let
        modelsList =
            RemoteData.withDefault [] state.allModels |> State.filterModelsByPerspective modelSearch

        showOnlyStronglyCoupled =
            modelSearch.showStronglyCoupled && not modelSearch.showNonStronglyCoupled

        showOnlyNonStronglyCoupled =
            modelSearch.showNonStronglyCoupled && not modelSearch.showStronglyCoupled

        models0 =
            modelsList
                |> applyWhen showOnlyStronglyCoupled (List.filter State.modelIsDynamic)
                |> applyWhen showOnlyNonStronglyCoupled (not << State.modelIsDynamic |> List.filter)
                |> applyWhen modelSearch.showCompositeOnly (List.filter .isHypermodel)

        models1 =
            if modelSearch.frozenOnly then
                List.filter .frozen models0
            else
                models0

        models2 =
            case modelSearch.title of
                Nothing ->
                    models1

                Just str ->
                    let
                        strU =
                            str |> String.toUpper |> String.words

                        matchesAll title =
                            List.all (\s -> String.contains s title) strU
                    in
                        List.filter (.title >> String.toUpper >> matchesAll) models1

        titleSearch =
            case modelSearch.title of
                Nothing ->
                    ""

                Just str ->
                    str

        breakListIn n lst =
            case lst of
                [] ->
                    []

                _ ->
                    List.take n lst :: breakListIn n (List.drop n lst)

        modalWin =
            modalWinIds ListModelsWin
    in
        div [ id modalWin, class "ui modal large scrolling" ]
            [ i [ class "ui right floated cancel close icon", onClick (CloseModal ListModelsWin) ] []
            , div [ class "header" ]
                [ div []
                    [ text "Available Models"
                    , div [ class "floating ui teal label" ]
                        [ text (models2 |> List.length |> toString)
                        ]
                    ]
                ]
            , div [ class "content" ]
                [ Html.form [ class "ui small form" ]
                    [ div [ class "field" ]
                        [ div [ class "ui icon input" ]
                            [ input [ type_ "text", placeholder "search in titles", value titleSearch, onInput (ModelSearchTitle >> ModelSearch) ] []
                            , i [ class "search icon" ] []
                            ]
                        ]
                    , div [ class "inline fields" ]
                        [ div [ class "field" ]
                            [ div
                                [ class "ui checkbox"
                                , attribute "data-tooltip" "Show stable ('frozen') models?"
                                ]
                                [ input
                                    [ type_ "checkbox"
                                    , checked modelSearch.frozenOnly
                                    , onCheck (ModelSearchFrozen >> ModelSearch)
                                    ]
                                    []
                                , label []
                                    [ text "Stable only" ]
                                ]
                            ]
                        , div [ class "field" ]
                            [ div
                                [ class "ui checkbox"
                                , attribute "data-tooltip" "Show strongly coupled models?"
                                ]
                                [ input
                                    [ type_ "checkbox"
                                    , checked modelSearch.showStronglyCoupled
                                    , onCheck (ModelSearchStronglyCoupled >> ModelSearch)
                                    ]
                                    []
                                , label []
                                    [ text "Strongly coupled" ]
                                ]
                            ]
                        , div [ class "field" ]
                            [ div
                                [ class "ui checkbox"
                                , attribute "data-tooltip" "Show non strongly coupled models?"
                                ]
                                [ input
                                    [ type_ "checkbox"
                                    , checked modelSearch.showNonStronglyCoupled
                                    , onCheck (ModelSearchNonStronglyCoupled >> ModelSearch)
                                    ]
                                    []
                                , label []
                                    [ text "Non strongly coupled" ]
                                ]
                            ]
                        , div [ class "field" ]
                            [ div
                                [ class "ui checkbox"
                                , attribute "data-tooltip" "Show only hypermodels?"
                                ]
                                [ input
                                    [ type_ "checkbox"
                                    , checked modelSearch.showCompositeOnly
                                    , onCheck (ModelSearchComposite >> ModelSearch)
                                    ]
                                    []
                                , label []
                                    [ text "Composite" ]
                                ]
                            ]
                        ]
                    , perspectives
                        |> breakListIn 3
                        |> List.map
                            (\p ->
                                div [ class "equal width fields" ]
                                    (List.map viewPerspectiveSelect p)
                            )
                        |> div []
                    ]
                , div [ style [ ( "height", "400px" ), ( "overflow-x", "scroll" ) ] ]
                    [ table [ class "ui small celled striped padded table" ]
                        [ thead [] [ tr [] [ th [] [ text "#" ], th [] [ text "Title" ], th [] [ text "Description" ], th [] [ text "Usage" ], th [] [ text "Add?" ] ] ]
                        , tbody [] (List.map (viewModel state) models2)
                        ]
                    ]
                ]
            , div [ class "actions" ]
                [ div [ class "ui cancel button", onClick (CloseModal ListModelsWin) ] [ text "Cancel" ] ]
            ]


viewSaveHypermodel : State.Hypermodel -> Html Msg
viewSaveHypermodel hm =
    -- This is a modal window
    let
        modalId =
            modalWinIds SaveHypermodelWin
    in
        div [ id modalId, class "ui small modal" ]
            [ i [ class "ui right floated cancel close icon", onClick (CloseModal SaveHypermodelWin) ] []
            , div [ class "header" ] [ text hm.title ]
            , div [ class "content" ]
                [ Html.form [ class "ui form" ]
                    [ div [ class "ui inverted segment grey" ]
                        [ text "ID:"
                        , hm.id |> text |> cons |> code []
                        , text " version:"
                        , hm.version |> text |> cons |> code []
                        ]
                    , div
                        [ class "field" ]
                        [ label [] [ text "Name" ]
                        , input [ onInput ChangeTitle, value hm.title ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Description" ]
                        , textarea [ onInput ChangeDescription, value hm.description ] []
                        ]
                    ]
                ]
            , div [ class "actions" ]
                [ div [ class "ui primary button", onClick DoSaveHypermodel ] [ text "Save" ]
                , div [ class "ui cancel button", onClick (CloseModal SaveHypermodelWin) ] [ text "Cancel" ]
                ]
            ]


view : State.State -> Html Msg
view state =
    let
        title =
            (if String.isEmpty state.wip.title then
                ""
             else
                ": " ++ state.wip.title ++ " (version: " ++ state.wip.version ++ ")"
            )
                |> applyWhen state.needsSaving (\tt -> String.append tt " *")

        loading =
            state.pendingRestCalls > 0 || RemoteData.isLoading state.allModels

        allModels =
            state.allModels |> RemoteData.withDefault []

        usedModels_ : List ( Graph.NodeId, Model )
        usedModels_ =
            usedModels state.wip.graph allModels

        freeInputsOfHypermodel : AllDict.AllDict Graph.NodeId (List ModelInOutput) Int
        freeInputsOfHypermodel =
            State.freeInputsOfHypermodel state.wip.graph allModels
                |> List.map (Tuple.mapFirst .id)
                |> AllDict.fromList Graph.ordNodeId

        loaderClasses =
            (if loading then
                "active"
             else
                "disabled"
            )
                :: [ "ui", "indeterminate", "text", "loader" ]
                |> addClasses

        hypermodels =
            state.allHypermodels |> RemoteData.withDefault []

        ( infoTitle, infoMsg ) =
            state.infoMessage
    in
        div [ class "ui" ]
            [ sidebar state
            , div [ class "pusher" ]
                [ h1 [ class "ui header centered" ]
                    [ a [ href "./" ] [ text "CHIC Hypermodeling Editor" ]
                    , text title
                    ]
                , toolbar state
                ]
            , div [ classList [ ( "ui inverted dimmer", True ), ( "active", loading ) ] ]
                [ div [ class loaderClasses ] [ text state.busyMessage ]
                ]
            , viewHypermodels allModels hypermodels
            , viewModels state state.modelSearch
            , viewSaveHypermodel state.wip
            , viewNodeDetails state
            , viewExportMML state.mml
            , viewErrorAlert state.serverError
            , viewInfoAlert infoTitle infoMsg
            , viewExperiments state.hotExperiments state.experiments
            , viewFillInputs usedModels_ freeInputsOfHypermodel state.executionInfo.inputs
            , viewConnectionValidityIssues state
            , viewRecommendations state
            ]
