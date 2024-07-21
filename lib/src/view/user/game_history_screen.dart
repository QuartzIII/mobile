import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/common/perf.dart';
import 'package:lichess_mobile/src/model/game/game_filter.dart';
import 'package:lichess_mobile/src/model/game/game_history.dart';
import 'package:lichess_mobile/src/model/user/user.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/view/game/game_list_tile.dart';
import 'package:lichess_mobile/src/widgets/adaptive_choice_picker.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';

class GameHistoryScreen extends ConsumerWidget {
  const GameHistoryScreen({
    required this.user,
    required this.isOnline,
    this.gameFilters = const GameFilterState(),
    super.key,
  });
  final LightUser? user;
  final bool isOnline;
  final GameFilterState gameFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConsumerPlatformWidget(
      ref: ref,
      androidBuilder: _buildAndroid,
      iosBuilder: _buildIos,
    );
  }

  Widget _buildIos(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(context.l10n.games)),
      child: _Body(user: user, isOnline: isOnline, gameFilters: gameFilters),
    );
  }

  Widget _buildAndroid(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.games)),
      body: _Body(user: user, isOnline: isOnline, gameFilters: gameFilters),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({
    required this.user,
    required this.isOnline,
    required this.gameFilters,
  });

  final LightUser? user;
  final bool isOnline;
  final GameFilterState gameFilters;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      final state = ref.read(
        userGameHistoryProvider(
          widget.user?.id,
          isOnline: widget.isOnline,
        ),
      );

      if (!state.hasValue) {
        return;
      }

      final hasMore = state.requireValue.hasMore;
      final isLoading = state.requireValue.isLoading;

      if (hasMore && !isLoading) {
        ref
            .read(
              userGameHistoryProvider(
                widget.user?.id,
                isOnline: widget.isOnline,
              ).notifier,
            )
            .getNext();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameFilterState =
        ref.watch(gameFilterProvider(perfs: widget.gameFilters.perfs));
    final gameListState = ref.watch(
      userGameHistoryProvider(
        widget.user?.id,
        isOnline: widget.isOnline,
        filters: gameFilterState,
      ),
    );

    final perfFilterLabel = gameFilterState.perfs.length == 1
        ? gameFilterState.perfs.first.title
        : '${context.l10n.timeControl} / ${context.l10n.variant}';

    return gameListState.when(
      data: (state) {
        final list = state.gameList;

        return SafeArea(
          child: Column(
            children: [
              Container(
                padding: Styles.bodyPadding,
                child: Row(
                  children: [
                    _MultipleChoiceFilter(
                      filterLabel: perfFilterLabel,
                      choices: const [
                        Perf.ultraBullet,
                        Perf.bullet,
                        Perf.blitz,
                        Perf.rapid,
                        Perf.classical,
                        Perf.correspondence,
                        Perf.chess960,
                        Perf.antichess,
                        Perf.kingOfTheHill,
                        Perf.threeCheck,
                        Perf.atomic,
                        Perf.horde,
                        Perf.racingKings,
                        Perf.crazyhouse,
                      ],
                      selectedItems: gameFilterState.perfs,
                      choiceLabelBuilder: (t) => Text(t.title),
                      onChanged: (value) => value != null
                          ? ref
                              .read(
                                gameFilterProvider(
                                  perfs: widget.gameFilters.perfs,
                                ).notifier,
                              )
                              .setPerfs(value)
                          : null,
                    ),
                  ],
                ),
              ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text(
                      'No games found',
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: list.length + (state.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (state.isLoading && index == list.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: CenterLoadingIndicator(),
                        );
                      } else if (state.hasError &&
                          state.hasMore &&
                          index == list.length) {
                        // TODO: add a retry button
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: Center(
                            child: Text(
                              'Could not load more games',
                            ),
                          ),
                        );
                      }

                      return ExtendedGameListTile(
                        item: list[index],
                        userId: widget.user?.id,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
      error: (e, s) {
        debugPrint(
          'SEVERE: [GameHistoryScreen] could not load game list',
        );
        return const Center(child: Text('Could not load Game History'));
      },
      loading: () => const CenterLoadingIndicator(),
    );
  }
}

class _MultipleChoiceFilter<T extends Enum> extends StatelessWidget {
  const _MultipleChoiceFilter({
    required this.filterLabel,
    required this.choices,
    required this.selectedItems,
    required this.choiceLabelBuilder,
    required this.onChanged,
  });

  final String filterLabel;
  final Iterable<T> choices;
  final Set<T> selectedItems;
  final Widget Function(T choice) choiceLabelBuilder;
  final void Function(Set<T>? value) onChanged;

  @override
  Widget build(BuildContext context) {
    return FatButton(
      semanticsLabel: filterLabel,
      onPressed: () => showMultipleChoicesPicker<T>(
        context,
        choices: choices,
        selectedItems: selectedItems,
        labelBuilder: choiceLabelBuilder,
      ).then(onChanged),
      child: Row(
        children: [
          if (selectedItems.length > 1)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${selectedItems.length}',
                textAlign: TextAlign.center,
              ),
            ),
          Text(' $filterLabel'),
        ],
      ),
    );
  }
}
