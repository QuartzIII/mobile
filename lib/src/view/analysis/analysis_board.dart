import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_preferences.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/eval.dart';
import 'package:lichess_mobile/src/model/engine/evaluation_preferences.dart';
import 'package:lichess_mobile/src/model/engine/evaluation_service.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/widgets/interactive_board.dart';
import 'package:lichess_mobile/src/widgets/pgn.dart';

class AnalysisBoard extends ConsumerStatefulWidget {
  const AnalysisBoard(
    this.options,
    this.boardSize, {
    this.borderRadius,
    this.enableDrawingShapes = true,
    this.shouldReplaceChildOnUserMove = false,
  });

  final AnalysisOptions options;
  final double boardSize;
  final BorderRadiusGeometry? borderRadius;

  final bool enableDrawingShapes;
  final bool shouldReplaceChildOnUserMove;

  @override
  ConsumerState<AnalysisBoard> createState() => AnalysisBoardState();
}

class AnalysisBoardState extends ConsumerState<AnalysisBoard> {
  ISet<Shape> userShapes = ISet();

  @override
  Widget build(BuildContext context) {
    final ctrlProvider = analysisControllerProvider(widget.options);
    final analysisState = ref.watch(ctrlProvider).requireValue;
    final boardPrefs = ref.watch(boardPreferencesProvider);
    final analysisPrefs = ref.watch(analysisPreferencesProvider);
    final enginePrefs = ref.watch(engineEvaluationPreferencesProvider);

    final enableComputerAnalysis = analysisState.isComputerAnalysisAllowedAndEnabled;
    final showBestMoveArrow = enableComputerAnalysis && analysisPrefs.showBestMoveArrow;
    final showAnnotationsOnBoard = enableComputerAnalysis && analysisPrefs.showAnnotations;
    final currentNode = analysisState.currentNode;

    final localBestMoves =
        analysisState.isEngineAvailable(enginePrefs) && showBestMoveArrow
            ? ref.watch(engineEvaluationProvider.select((value) => value.eval?.bestMoves))
            : null;
    final bestMoves = pickBestMoves(localBestMoves: localBestMoves, savedEval: currentNode.eval);
    final ISet<Shape> bestMoveShapes =
        bestMoves != null && showBestMoveArrow
            ? computeBestMoveShapes(
              bestMoves,
              currentNode.position.turn,
              boardPrefs.pieceSet.assets,
            )
            : ISet();

    final annotation = showAnnotationsOnBoard ? makeAnnotation(currentNode.nags) : null;
    final sanMove = currentNode.sanMove;

    return InteractiveBoardWidget(
      boardPrefs: boardPrefs,
      size: widget.boardSize,
      fen: analysisState.currentPosition.fen,
      lastMove: analysisState.lastMove as NormalMove?,
      orientation: analysisState.pov,
      gameData: GameData(
        playerSide:
            analysisState.currentPosition.isGameOver
                ? PlayerSide.none
                : analysisState.currentPosition.turn == Side.white
                ? PlayerSide.white
                : PlayerSide.black,
        isCheck: boardPrefs.boardHighlights && analysisState.currentPosition.isCheck,
        sideToMove: analysisState.currentPosition.turn,
        validMoves: analysisState.validMoves,
        promotionMove: analysisState.promotionMove,
        onMove:
            (move, {isDrop, captured}) => ref
                .read(ctrlProvider.notifier)
                .onUserMove(move, shouldReplace: widget.shouldReplaceChildOnUserMove),
        onPromotionSelection: (role) => ref.read(ctrlProvider.notifier).onPromotionSelection(role),
      ),
      shapes: userShapes.union(bestMoveShapes),
      annotations:
          showAnnotationsOnBoard && sanMove != null && annotation != null
              ? altCastles.containsKey(sanMove.move.uci)
                  ? IMap({Move.parse(altCastles[sanMove.move.uci]!)!.to: annotation})
                  : IMap({sanMove.move.to: annotation})
              : null,
      settings: boardPrefs.toBoardSettings().copyWith(
        borderRadius: widget.borderRadius,
        boxShadow: widget.borderRadius != null ? boardShadows : const <BoxShadow>[],
        drawShape: DrawShapeOptions(
          enable: widget.enableDrawingShapes,
          onCompleteShape: _onCompleteShape,
          onClearShapes: _onClearShapes,
          newShapeColor: boardPrefs.shapeColor.color,
        ),
      ),
    );
  }

  void _onCompleteShape(Shape shape) {
    if (userShapes.any((element) => element == shape)) {
      setState(() {
        userShapes = userShapes.remove(shape);
      });
      return;
    } else {
      setState(() {
        userShapes = userShapes.add(shape);
      });
    }
  }

  void _onClearShapes() {
    setState(() {
      userShapes = ISet();
    });
  }
}
