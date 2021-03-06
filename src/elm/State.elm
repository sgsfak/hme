module State exposing (..)

import AllDict
import Date exposing (Date)
import Dict
import Set
import Either exposing (Either(..), lefts, rights)
import Graph
import Http
import List.Extra
import Number.Expanded exposing (..)
import Random.Pcg exposing (Seed, initialSeed, step)
import RemoteData exposing (WebData)
import Utils exposing (..)
import Uuid


type alias UUID =
    { currentSeed : Seed
    , currentUuid : Uuid.Uuid
    }


type alias Hypermodel =
    { title : String
    , id : String
    , description : String
    , version : String
    , canvas : String
    , created : Date
    , updated : Date
    , svgContent : String
    , graph : Graph.Graph
    , publishedRepoId : Maybe Int
    }


emptyHypermodel : String -> Hypermodel
emptyHypermodel id =
    { title = ""
    , id = id
    , description = ""
    , version = ""
    , canvas = ""
    , created = Date.fromTime 0
    , updated = Date.fromTime 0
    , svgContent = ""
    , graph = Graph.new id
    , publishedRepoId = Nothing
    }


type alias ValueRange =
    ( Expanded Float, Expanded Float )


type alias ModelInOutput =
    { repoId : Int
    , uuid : String
    , name : String
    , isDynamic : Bool
    , isMandatory : Bool
    , dataType : String
    , units : String
    , description : String
    , range : Maybe ValueRange
    , defaultValue : Maybe String
    , semtype : List String
    , meaningUri : Maybe String
    , unitsUri : Maybe String
    }


type ModelInputWithValue
    = ModelInputWithValue ModelInOutput String


type alias Perspective =
    { index : Int, name : String, uri : String, values : List ( String, String ) }


unitsOntologyMap : Dict.Dict String String
unitsOntologyMap =
    Dict.fromList
        [ "http://www.chic-vph.eu/ontologies#chic_0002115" => "second"
        , "http://www.chic-vph.eu/ontologies#chic_0002113" => "hour"
        , "http://www.chic-vph.eu/ontologies#chic_0002203" => "percent"
        , "http://www.chic-vph.eu/ontologies#chic_0002131" => "millimeter"
        , "http://www.chic-vph.eu/ontologies#chic_0002201" => "square millimeter per hour"
        , "http://www.chic-vph.eu/ontologies#chic_0002111" => "year"
        , "http://www.chic-vph.eu/ontologies#chic_0002202" => "kilogram per cubic meter"
        , "http://www.chic-vph.eu/ontologies#chic_0002112" => "day"
        , "http://www.chic-vph.eu/ontologies#chic_0002153" => "cubic centimeter"
        , "http://www.chic-vph.eu/ontologies#chic_0002116" => "month"
        , "http://www.chic-vph.eu/ontologies#chic_0002171" => "per hour"
        , "http://www.chic-vph.eu/ontologies#chic_0002151" => "liter"
        , "http://www.chic-vph.eu/ontologies#chic_0002152" => "milliliter"
        , "http://www.chic-vph.eu/ontologies#chic_0002154" => "gray"
        , "http://www.chic-vph.eu/ontologies#chic_0002211" => "radian (unit)"
        , "http://www.chic-vph.eu/ontologies#chic_0002212" => "per cubic millimeter (unit)"
        ]


meaningOntologyMap : Dict.Dict String String
meaningOntologyMap =
    Dict.fromList
        [ "http://www.chic-vph.eu/ontologies#chic_0001024" => "rate of proliferation of cell population"
        , "http://purl.org/obo/owlapi/quality#PATO_0000070" => "count"
        , "http://purl.org/obo/owlapi/quality#PATO_0000918" => "volume"
        , "http://www.chic-vph.eu/ontologies#chic_0001021" => "doubling time (duration)"
        , "http://purl.org/obo/owlapi/quality#PATO_0000011" => "age"
        , "http://www.chic-vph.eu/ontologies#chic_0001022" => "percentage (ratio)"
        , "http://www.chic-vph.eu/ontologies#chic_0001020" => "timepoint (duration to)"
        , "http://purl.org/obo/owlapi/quality#PATO_0000161" => "rate"
        , "http://purl.org/obo/owlapi/quality#PATO_0001309" => "duration"
        , "http://purl.org/obo/owlapi/quality#PATO_0001745" => "radiation absorbed dose"
        , "http://www.chic-vph.eu/ontologies#chic_0001023" => "probability (ratio)"
        , "http://www.chic-vph.eu/ontologies#chic_0001025" => "cell kill rate (probability)"
        , "http://purl.org/obo/owlapi/quality#PATO_0000033" => "concentration"
        , "http://www.chic-vph.eu/ontologies#chic_0001026" => "count of cells in population"
        , "http://purl.org/obo/owlapi/quality#PATO_0002326" => "angle"
        , "http://purl.org/obo/owlapi/quality#PATO_0001470" => "ratio"
        ]


perspective1 : Perspective
perspective1 =
    Perspective 1
        "Tumor-affected normal tissue modelling"
        "http://www.chic-vph.eu/ontologies/resource#hasPositionIn-1"
        [ "http://purl.obolibrary.org/obo/HP_0002664" => "Tumor"
        , "http://purl.obolibrary.org/obo/HP_0000969" => "Oedima"
        ]


perspective2 : Perspective
perspective2 =
    Perspective 2
        "Spatial scales"
        "http://www.chic-vph.eu/ontologies/resource#hasPositionIn-2"
        [ "http://www.chic-vph.eu/ontologies#chic_0000201" => "Atomic"
        , "http://www.chic-vph.eu/ontologies#chic_0000202" => "Molecular"
        , "http://www.chic-vph.eu/ontologies#chic_0000203" => "Cellular"
        , "http://www.chic-vph.eu/ontologies#chic_0000204" => "Tissue"
        , "http://www.chic-vph.eu/ontologies#chic_0000205" => "Organ"
        , "http://www.chic-vph.eu/ontologies#chic_0000206" => "Body system"
        , "http://www.chic-vph.eu/ontologies#chic_0000207" => "Organism"
        , "http://www.chic-vph.eu/ontologies#chic_0000208" => "Population"
        ]


perspective4 : Perspective
perspective4 =
    Perspective 4
        "Biomechanism(s) addressed"
        "http://www.chic-vph.eu/ontologies/resource#hasPositionIn-4"
        [ "http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#C19323" => "Basic tumour biology"
        , "http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#C16346" => "Biomechanics"
        , "http://purl.obolibrary.org/obo/GO_0003674" => "Molecular"
        , "http://purl.obolibrary.org/obo/GO_0008150" => "Angiogenesis"
        , "http://purl.obolibrary.org/obo/GO_0008152" => "Metabolism"
        , "http://purl.obolibrary.org/obo/GO_0022402" => "Cell cycle"
        , "http://purl.obolibrary.org/obo/GO_0070265" => "Necrosis"
        ]


chicHypermodellingBestPractice : Set.Set String
chicHypermodellingBestPractice =
    [ "http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#C19323"
    , "http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#C16346"
    , "http://purl.obolibrary.org/obo/GO_0003674"
    , "http://purl.obolibrary.org/obo/GO_0008150"
    , "http://purl.obolibrary.org/obo/GO_0008152"
    ]
        |> Set.fromList


perspective5 : Perspective
perspective5 =
    Perspective 5
        "Tumour type(s) addressed"
        "http://www.chic-vph.eu/ontologies/resource#hasPositionIn-5"
        [ "http://purl.obolibrary.org/obo/HP_0100526" => "Lung cancer"
        , "http://purl.obolibrary.org/obo/HP_0002667" => "Wilm's tumor"
        , "http://purl.obolibrary.org/obo/HP_0003003" => "Colon cancer"
        , "http://purl.obolibrary.org/obo/HP_0012125" => "Prostate cancer"
        , "http://purl.obolibrary.org/obo/HP_0100843" => "Glioblastoma"
        ]


perspective8 : Perspective
perspective8 =
    Perspective 8
        "Order of Addressing Spatial scales"
        "http://www.chic-vph.eu/ontologies/resource#hasPositionIn-8"
        [ "http://www.chic-vph.eu/ontologies#chic_0000211" => "Bottom-Up"
        , "http://www.chic-vph.eu/ontologies#chic_0000212" => "Middle-Out"
        , "http://www.chic-vph.eu/ontologies#chic_0000213" => "Top-Down"
        ]


perspectives : List Perspective
perspectives =
    [ perspective1
    , perspective2
    , perspective4
    , perspective5
    , perspective8
    ]


type alias Model =
    { title : String
    , id : Int
    , uuid : String
    , description : String
    , frozen : Bool
    , inPorts : List ModelInOutput
    , outPorts : List ModelInOutput
    , annotations :
        Dict.Dict String (List String)
    , usage : Int
    , isHypermodel : Bool
    }


findInputParam : Model -> String -> Maybe ModelInOutput
findInputParam { inPorts } param =
    List.Extra.find (.name >> (==) param) inPorts


findOutputParam : Model -> String -> Maybe ModelInOutput
findOutputParam { outPorts } param =
    List.Extra.find (.name >> (==) param) outPorts


type alias ModelExecutionInputs =
    Dict.Dict String String


{-| A list of pairs of node ids and the corresponding inputs the user has filled in
-}
type alias HypermodelExecutionInput =
    AllDict.AllDict Graph.NodeId ModelExecutionInputs Int


type alias ExecutionInfo =
    { inputs : HypermodelExecutionInput
    , useCaching : Set.Set Int
    }


type alias ModelSearchState =
    { title : Maybe String
    , frozenOnly : Bool
    , showStronglyCoupled : Bool
    , showNonStronglyCoupled : Bool
    , perspectives : Dict.Dict String String
    , showCompositeOnly : Bool
    }


type ModalWin
    = ListModelsWin
    | ListHypermodelsWin
    | SaveHypermodelWin
    | NodeDetailsWin
    | ErrorWin
    | InfoWin
    | XMMLWin
    | LaunchExecutionWin
    | ShowExperimentsWin
    | ShowIssuesWin
    | ShowRecommendationsWin


type alias ModalWinState =
    { openModals : List ModalWin
    }


type AlertError
    = HttpError Http.Error
    | OtherError (List String)
    | NoError


type alias ExperimentUuid =
    String


type ExperimentStatus
    = NOT_STARTED
    | RUNNING
    | FINISHED_FAIL
    | FINISHED_OK


type alias Experiment =
    { uuid : ExperimentUuid
    , hypermodelId : String
    , experimentRepoId : Int
    , status : ExperimentStatus
    , title : String
    , version : Int
    }


type alias Experiments =
    List Experiment


type alias ModelParamIndexEntry =
    { modelUuid : String
    , param : ModelInOutput
    , isInput : Bool
    }


type alias ModelIndexes =
    { byMeaningURI : Dict.Dict String (List ModelParamIndexEntry)
    , byUnitsURI : Dict.Dict String (List ModelParamIndexEntry)
    }


type alias ModelRecommendations =
    { asNext : List ModelParamIndexEntry, asPrev : List ModelParamIndexEntry }


type alias State =
    { loadedHypermodel : Maybe Hypermodel
    , wip : Hypermodel
    , mml : String
    , selectedNode : Maybe Graph.NodeId
    , needsSaving : Bool
    , pendingRestCalls : Int
    , busyMessage : String
    , uuid : UUID
    , allHypermodels : WebData (List Hypermodel)
    , allModels : WebData (List Model)
    , modalsState : ModalWinState
    , zoomLevel : Float
    , modelSearch : ModelSearchState
    , executionInfo : ExecutionInfo
    , serverError : AlertError
    , infoMessage : ( String, String )
    , experiments : List Experiment
    , hotExperiments : Dict.Dict ExperimentUuid ExperimentStatus
    , notificationCount : Int
    , connectionsValidity : ConnectionValidityResult
    , indexes : ModelIndexes
    , recommendations : ModelRecommendations
    }


modelIsDynamic : Model -> Bool
modelIsDynamic model =
    let
        hasDynamicPort ports =
            List.any .isDynamic ports
    in
        hasDynamicPort model.inPorts || hasDynamicPort model.outPorts


modelIsUsed : State -> Model -> Bool
modelIsUsed state model =
    let
        nodes =
            Graph.nodes state.wip.graph

        modelId =
            model.uuid
    in
        List.any
            (\n ->
                case n.kind of
                    Graph.ModelNode u ->
                        u == modelId
            )
            nodes


perspValueForModel : Model -> Perspective -> List String
perspValueForModel { annotations } { uri, values } =
    let
        findValUri : String -> Maybe String
        findValUri uri =
            listFind ((==) uri << Tuple.first) values |> Maybe.map Tuple.second
    in
        Dict.get uri annotations |> Maybe.map (List.filterMap findValUri) |> Maybe.withDefault []


tagsForModel : Model -> List String
tagsForModel model =
    List.concatMap (perspValueForModel model) perspectives


tagsForHyperModel : List Model -> Hypermodel -> List String
tagsForHyperModel allModels hypermodel =
    let
        models =
            modelsOfHypermodel allModels hypermodel

        persps =
            [ perspective1, perspective4 ]
    in
        List.concatMap (\m -> List.concatMap (perspValueForModel m) persps) models
            |> List.Extra.unique


modelsOfHypermodel : List Model -> Hypermodel -> List Model
modelsOfHypermodel allModels { graph } =
    let
        ids =
            Graph.nodes graph |> List.map .kind |> List.map (\(Graph.ModelNode s) -> s)
    in
        allModels |> List.filter (\{ uuid } -> List.member uuid ids)


initModelSearch : ModelSearchState
initModelSearch =
    { title = Nothing
    , frozenOnly = False
    , showStronglyCoupled = True
    , showNonStronglyCoupled = True
    , perspectives = Dict.empty
    , showCompositeOnly = False
    }


updateModelSearchPersp : ModelSearchState -> String -> Maybe String -> ModelSearchState
updateModelSearchPersp ({ perspectives } as state) uri maybeValue =
    let
        persp =
            case maybeValue of
                Nothing ->
                    Dict.remove uri perspectives

                Just s ->
                    Dict.insert uri s perspectives
    in
        { state | perspectives = persp }


filterModelsByPerspective : ModelSearchState -> List Model -> List Model
filterModelsByPerspective { perspectives } models =
    let
        check2 modelPersps =
            Dict.map (\puri pvalue -> Dict.get puri modelPersps |> Maybe.map (\v -> List.member pvalue v) |> Maybe.withDefault False) perspectives
                |> Dict.values
                |> List.all identity
    in
        List.filter (.annotations >> check2) models


initCanvasState : State -> State
initCanvasState state =
    let
        ( uuid, state2 ) =
            newUuid state

        u =
            uuid |> Uuid.toString
    in
        { state2
            | loadedHypermodel = Nothing
            , wip =
                emptyHypermodel u
            , mml = ""
            , selectedNode = Nothing
            , needsSaving = False
            , modalsState = { openModals = [] }
            , busyMessage = "Loading.."
            , zoomLevel = 1.0
        }


initializeState : State -> State
initializeState state =
    let
        state2 =
            initCanvasState state
    in
        { state2
            | allHypermodels = RemoteData.NotAsked
            , allModels = RemoteData.NotAsked
            , modelSearch = initModelSearch
        }


toggleCaching : Set.Set Int -> Graph.NodeId -> Bool -> Set.Set Int
toggleCaching intSetSet nodeIdGraph enabled =
    let
        nid =
            Graph.ordNodeId nodeIdGraph
    in
        if enabled then
            Set.insert nid intSetSet
        else
            Set.remove nid intSetSet


initExecutionInfo : ExecutionInfo
initExecutionInfo =
    { inputs = AllDict.empty Graph.ordNodeId
    , useCaching = Set.empty
    }


init : Int -> ( State, Cmd a )
init seed =
    let
        ( newUuid, newSeed ) =
            step Uuid.uuidGenerator (initialSeed seed)

        u =
            Uuid.toString newUuid

        initialState =
            { loadedHypermodel = Nothing
            , wip = emptyHypermodel u
            , mml = ""
            , selectedNode = Nothing
            , needsSaving = False
            , allHypermodels = RemoteData.NotAsked
            , allModels = RemoteData.NotAsked
            , modalsState = { openModals = [] }
            , pendingRestCalls = 0
            , busyMessage = "Loading.."
            , zoomLevel = 1.0
            , uuid =
                { currentSeed = newSeed
                , currentUuid = newUuid
                }
            , modelSearch = initModelSearch
            , executionInfo = initExecutionInfo
            , serverError = NoError
            , infoMessage = ( "", "" )
            , experiments = []
            , hotExperiments = Dict.empty
            , notificationCount = 0
            , connectionsValidity = ConnectionValid
            , indexes = { byMeaningURI = Dict.empty, byUnitsURI = Dict.empty }
            , recommendations = { asNext = [], asPrev = [] }
            }
    in
        ( initialState
        , Cmd.none
        )


updateModels : List Model -> State -> State
updateModels models state =
    let
        ms =
            List.sortBy .title models

        mkIndexPerModel : (ModelInOutput -> Maybe String) -> Bool -> Model -> List ( String, ModelParamIndexEntry )
        mkIndexPerModel g input model =
            List.filterMap
                (\p ->
                    case (g p) of
                        Just m ->
                            Just
                                ( m
                                , { modelUuid = model.uuid, param = p, isInput = input }
                                )

                        _ ->
                            Nothing
                )
                (if input then
                    model.inPorts
                 else
                    model.outPorts
                )

        meaningsIndex =
            List.concat
                [ List.concatMap (mkIndexPerModel .meaningUri True) models
                , List.concatMap (mkIndexPerModel .meaningUri False) models
                ]
                |> Utils.groupListToDict

        unitsIndex =
            List.concat
                [ List.concatMap (mkIndexPerModel .unitsUri True) models
                , List.concatMap (mkIndexPerModel .unitsUri False) models
                ]
                |> Utils.groupListToDict

        oldIndexes =
            state.indexes

        newIndexes =
            { oldIndexes | byMeaningURI = meaningsIndex, byUnitsURI = unitsIndex }
    in
        { state | allModels = RemoteData.Success ms, indexes = newIndexes }


updateHypermodels : List Hypermodel -> State -> State
updateHypermodels hypermodels state =
    { state | allHypermodels = List.sortBy .title hypermodels |> RemoteData.Success }


findModelByUUID : List Model -> String -> Maybe Model
findModelByUUID list uuid =
    case list of
        [] ->
            Nothing

        first :: rest ->
            if first.uuid == uuid then
                Just first
            else
                findModelByUUID rest uuid


findModel : State -> String -> Maybe Model
findModel state uuid =
    RemoteData.toMaybe state.allModels
        |> Maybe.andThen (\allModels -> findModelByUUID allModels uuid)


type ConnectionValidityError
    = ConnectionMeaningMatchError String String
    | ConnectionUnitsMatchError String String
    | ConnectionRangeMatchError ValueRange ValueRange


type ConnectionValidityInfo
    = ConnectionValidityInfo { source : ModelInOutput, target : ModelInOutput }


type ConnectionValidityResult
    = ConnectionValid
    | ConnectionInvalid ConnectionValidityInfo (List ConnectionValidityError)


validateConnection : State -> Graph.Connection -> ConnectionValidityResult
validateConnection state { sourceId, sourcePort, targetId, targetPort } =
    let
        sourceModel : Maybe Model
        sourceModel =
            Graph.findModelNode state.wip.graph sourceId |> Maybe.andThen (findModel state)

        targetModel : Maybe Model
        targetModel =
            Graph.findModelNode state.wip.graph targetId |> Maybe.andThen (findModel state)

        sourceParam =
            sourceModel |> Maybe.andThen (\model -> findOutputParam model sourcePort)

        targetParam =
            targetModel |> Maybe.andThen (\model -> findInputParam model targetPort)
    in
        Maybe.map2
            (\s t ->
                let
                    errors =
                        checkPossibleConnection s t
                in
                    if List.isEmpty errors then
                        ConnectionValid
                    else
                        ConnectionInvalid (ConnectionValidityInfo { source = s, target = t }) errors
            )
            sourceParam
            targetParam
            |> Maybe.withDefault ConnectionValid


checkPossibleConnection : ModelInOutput -> ModelInOutput -> List ConnectionValidityError
checkPossibleConnection sourceParam targetParam =
    let
        ma : List ConnectionValidityError
        ma =
            Maybe.map2
                (\m1 m2 ->
                    if m1 == m2 then
                        []
                    else
                        [ ConnectionMeaningMatchError m1 m2 ]
                )
                sourceParam.meaningUri
                targetParam.meaningUri
                |> Maybe.withDefault []

        mb : List ConnectionValidityError
        mb =
            Maybe.map2
                (\u1 u2 ->
                    if u1 == u2 then
                        []
                    else
                        [ ConnectionUnitsMatchError u1 u2 ]
                )
                sourceParam.unitsUri
                targetParam.unitsUri
                |> Maybe.withDefault []

        mc : List ConnectionValidityError
        mc =
            Maybe.map2
                (\vr1 vr2 ->
                    if valueRangesIntersect vr1 vr2 then
                        []
                    else
                        [ ConnectionRangeMatchError vr1 vr2 ]
                )
                sourceParam.range
                targetParam.range
                |> Maybe.withDefault []

        allErrors =
            ma ++ mb ++ mc
    in
        allErrors


findSelectedModel : State -> Maybe Model
findSelectedModel state =
    state.selectedNode
        |> Maybe.andThen (Graph.findNode state.wip.graph)
        |> Maybe.map
            (\n ->
                case n.kind of
                    Graph.ModelNode modelId ->
                        modelId
            )
        |> Maybe.andThen (findModel state)


findHypermodelByUUID : String -> List Hypermodel -> Maybe Hypermodel
findHypermodelByUUID uuid list =
    case list of
        [] ->
            Nothing

        first :: rest ->
            if first.id == uuid then
                Just first
            else
                findHypermodelByUUID uuid rest


newUuid : State -> ( Uuid.Uuid, State )
newUuid state =
    let
        ( newUuid, newSeed ) =
            step Uuid.uuidGenerator state.uuid.currentSeed

        u_ =
            { currentUuid = newUuid
            , currentSeed = newSeed
            }
    in
        ( newUuid, { state | uuid = u_ } )


{-| Given an integer it returns a list of UUIDs of this size
-}
newUuids : Int -> State -> ( List Uuid.Uuid, State )
newUuids n state =
    let
        newUuidsAux : Int -> List Uuid.Uuid -> State -> ( List Uuid.Uuid, State )
        newUuidsAux n sofar state =
            case n of
                0 ->
                    ( sofar
                    , state
                    )

                _ ->
                    let
                        ( uuid, newstate ) =
                            newUuid state

                        uuids =
                            uuid :: sofar

                        remaining =
                            n - 1
                    in
                        newUuidsAux remaining uuids newstate
    in
        newUuidsAux n [] state


newHypermodel : State -> State
newHypermodel state =
    initCanvasState state


isEmptyCanvas : State -> Bool
isEmptyCanvas state =
    state.wip.graph |> Graph.nodes |> List.isEmpty |> not


usedModels : Graph.Graph -> List Model -> List ( Graph.NodeId, Model )
usedModels graph allModels =
    Graph.modelNodes graph
        |> List.filterMap (Tuple.mapSecond (findModelByUUID allModels) >> Utils.liftMaybeToTuple)


hypermodelIsStronglyCoupled : Hypermodel -> List Model -> Bool
hypermodelIsStronglyCoupled { graph } allModels =
    usedModels graph allModels |> List.map Tuple.second |> List.any modelIsDynamic


freeParamsOfHypermodel : Bool -> Graph.Graph -> List Model -> List ( Graph.Node, List ModelInOutput )
freeParamsOfHypermodel checkInputs graph listModels =
    let
        allModels : Dict.Dict String Model
        allModels =
            listModels |> List.Extra.zip (List.map .uuid listModels) |> Dict.fromList

        nodes =
            Graph.nodes graph

        partitionParams : Graph.NodeId -> List (Either String String)
        partitionParams nodeId =
            Graph.connectionsOfNode nodeId graph
                |> List.map
                    (\conn ->
                        if conn.targetId == nodeId then
                            Left conn.targetPort
                        else
                            Right conn.sourcePort
                    )

        freeParamsOf_ : Graph.NodeId -> Model -> List ModelInOutput
        freeParamsOf_ nodeId { inPorts, outPorts } =
            let
                connectedParams =
                    if checkInputs then
                        partitionParams nodeId |> lefts
                    else
                        partitionParams nodeId |> rights

                ports =
                    if checkInputs then
                        inPorts
                    else
                        outPorts
            in
                ports |> List.filter (\{ name } -> not <| List.member name connectedParams)

        freeParamsOf : Graph.Node -> Maybe ( Graph.Node, List ModelInOutput )
        freeParamsOf ({ id, kind } as node) =
            case kind of
                Graph.ModelNode uuid ->
                    Dict.get uuid allModels |> Maybe.map (freeParamsOf_ id >> (=>) node)
    in
        List.filterMap freeParamsOf nodes


paramsOfHypermodelNewNames : Bool -> Graph.Graph -> List Model -> List ( Graph.Node, List ( ModelInOutput, String ) )
paramsOfHypermodelNewNames checkInputs graph listModels =
    let
        params : List ( Graph.Node, List ModelInOutput )
        params =
            freeParamsOfHypermodel checkInputs graph listModels

        f : Graph.NodeId -> List ModelInOutput -> Set.Set String -> ( List ( ModelInOutput, String ), Set.Set String )
        f (Graph.NodeId nodeId) params currentUsedNames =
            let
                newName name =
                    "i" ++ toString nodeId ++ "_" ++ name

                newNames : List ( ModelInOutput, String )
                newNames =
                    List.map
                        (\({ name } as p) ->
                            if Set.member name currentUsedNames then
                                ( p, newName name )
                            else
                                ( p, name )
                        )
                        params

                newUsedNames =
                    List.map Tuple.second newNames |> List.foldl Set.insert currentUsedNames |> Debug.log "Current USed:"

                -- result : List ( ModelInOutput, String )
                -- result =
                --     newNames
                --         |> List.map
                --             (\( { name } as p, m ) ->
                --                 case m of
                --                     Just newname ->
                --                         ( p, newname )
                --
                --                     _ ->
                --                         ( p, name )
                --             )
            in
                ( newNames, newUsedNames )

        ( finalResult, _ ) =
            List.foldl
                (\( { id } as node, nodeParams ) ( result, currentNames ) ->
                    let
                        ( p, newUsedNames ) =
                            f id nodeParams currentNames
                    in
                        ( ( node, p ) :: result, newUsedNames )
                )
                ( [], Set.empty )
                params
    in
        finalResult


freeInputsOfHypermodel : Graph.Graph -> List Model -> List ( Graph.Node, List ModelInOutput )
freeInputsOfHypermodel =
    freeParamsOfHypermodel True


freeOutputsOfHypermodel : Graph.Graph -> List Model -> List ( Graph.Node, List ModelInOutput )
freeOutputsOfHypermodel =
    freeParamsOfHypermodel False


inputsOfHypermodelNewNames : Graph.Graph -> List Model -> List ( Graph.Node, List ( ModelInOutput, String ) )
inputsOfHypermodelNewNames =
    paramsOfHypermodelNewNames True


outputsOfHypermodelNewNames : Graph.Graph -> List Model -> List ( Graph.Node, List ( ModelInOutput, String ) )
outputsOfHypermodelNewNames =
    paramsOfHypermodelNewNames False


overrideFilledInputs : String -> String -> ModelExecutionInputs -> ModelExecutionInputs
overrideFilledInputs param value =
    Dict.insert param value


emptyExecutionInputs : HypermodelExecutionInput
emptyExecutionInputs =
    AllDict.empty Graph.ordNodeId


executionInputFor : HypermodelExecutionInput -> Graph.NodeId -> String -> Maybe String
executionInputFor executionInputs nodeId paramName =
    AllDict.get nodeId executionInputs |> Maybe.andThen (Dict.get paramName)


newExperiment : Experiment -> State -> State
newExperiment experiment state =
    { state | experiments = experiment :: state.experiments }


expandedLowerThan : Expanded comparable -> Expanded comparable -> Bool
expandedLowerThan exp1 exp2 =
    case exp1 of
        Finite number1 ->
            case exp2 of
                Finite number2 ->
                    number1 < number2

                PosInfinity ->
                    True

                NegInfinity ->
                    False

        PosInfinity ->
            False

        NegInfinity ->
            True


valueRangeValid : ValueRange -> Bool
valueRangeValid ( exp1, exp2 ) =
    expandedLowerThan exp1 exp2


valueRangesIntersect : ValueRange -> ValueRange -> Bool
valueRangesIntersect ( low1, up1 ) ( low2, up2 ) =
    let
        noIntersection =
            expandedLowerThan up1 low2 || expandedLowerThan up2 low1
    in
        not noIntersection
