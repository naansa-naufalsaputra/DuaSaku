import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:duasaku_app/features/wallets/domain/models/wallet_model.dart';

class WalletStackedLayout extends StatefulWidget {
  final List<WalletModel> wallets;
  final bool isDark;
  final double monthlyIncome;
  final double monthlyExpense;
  final NumberFormat formatCurrency;

  const WalletStackedLayout({
    super.key,
    required this.wallets,
    required this.isDark,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.formatCurrency,
  });

  @override
  State<WalletStackedLayout> createState() => _WalletStackedLayoutState();
}

class _WalletStackedLayoutState extends State<WalletStackedLayout>
    with TickerProviderStateMixin {
  late final AnimationController _openController;
  late final AnimationController _expansionController;
  int? _animatingIndex;

  @override
  void initState() {
    super.initState();
    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _expansionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _openController.dispose();
    _expansionController.dispose();
    super.dispose();
  }

  List<Color> _getGradientForType(String type) {
    switch (type.toLowerCase()) {
      case 'bank':
        return const [Color(0xFF0056B3), Color(0xFF007AFF)];
      case 'e-wallet':
        return const [Color(0xFF475569), Color(0xFF64748B)];
      case 'cash':
        return const [Color(0xFF1E293B), Color(0xFF334155)];
      default:
        return const [Color(0xFF334155), Color(0xFF475569)];
    }
  }

  String _formatAbbreviated(double amount) {
    final sym = widget.formatCurrency.currencySymbol.trim();
    if (amount >= 1000000) {
      final val = amount / 1000000.0;
      final valStr = val == val.toInt()
          ? val.toInt().toString()
          : val.toStringAsFixed(1);
      return '$sym ${valStr}M';
    } else if (amount >= 1000) {
      final val = amount / 1000.0;
      final valStr = val == val.toInt()
          ? val.toInt().toString()
          : val.toStringAsFixed(1);
      return '$sym ${valStr}k';
    } else {
      return '$sym ${amount.toStringAsFixed(0)}';
    }
  }

  void _handleCardTap(int index, String walletId) {
    if (_animatingIndex != null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _animatingIndex = index;
    });
    _openController.forward().then((_) {
      if (mounted) {
        context.push('/wallets/$walletId').then((_) {
          if (mounted) {
            _openController.reverse().then((_) {
              if (mounted) {
                setState(() {
                  _animatingIndex = null;
                });
              }
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = widget.formatCurrency;
    final L = widget.wallets.length;

    const double cardHeight = 125.0;
    final double totalBalance = widget.wallets.fold(
      0.0,
      (sum, w) => sum + w.balance,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_openController, _expansionController]),
      builder: (context, child) {
        final double animatedStep = 40.0 + (_expansionController.value * 80.0);
        final double totalHeight = cardHeight + (L * animatedStep) + 10.0;

        final double expansionProgress = _expansionController.value;
        final double scaleFactor = 0.035 - (expansionProgress * 0.02);

        return RepaintBoundary(
          child: SizedBox(
            height: totalHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_animatingIndex != null) return;
                HapticFeedback.lightImpact();
                if (_expansionController.isAnimating) return;
                if (_expansionController.value > 0.5) {
                  _expansionController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                  );
                } else {
                  _expansionController.animateTo(
                    1.0,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                  );
                }
              },
              onVerticalDragUpdate: (details) {
                if (_animatingIndex != null) return;
                final double delta = -details.delta.dy / 150.0;
                _expansionController.value =
                    (_expansionController.value + delta).clamp(0.0, 1.0);
              },
              onVerticalDragEnd: (details) {
                if (_animatingIndex != null) return;
                final double velocity = details.primaryVelocity ?? 0.0;
                if (velocity < -300) {
                  _expansionController.animateTo(
                    1.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                } else if (velocity > 300) {
                  _expansionController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                } else {
                  if (_expansionController.value >= 0.5) {
                    _expansionController.animateTo(
                      1.0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                    );
                  } else {
                    _expansionController.animateTo(
                      0.0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                    );
                  }
                }
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ...List.generate(L, (index) {
                    final wallet = widget.wallets[index];
                    final isTarget = _animatingIndex == index;
                    final isAnyTarget = _animatingIndex != null;

                    final int reversePos = L - index;
                    final double normalOffsetY = -reversePos * animatedStep;
                    final double normalScale = 1.0 - (reversePos * scaleFactor);
                    final double normalOpacity = 0.7 + (index / L) * 0.3;

                    double offsetY = normalOffsetY;
                    double scale = normalScale;
                    double opacity = normalOpacity;

                    if (isTarget) {
                      offsetY =
                          normalOffsetY + (_openController.value * -130.0);
                      scale =
                          normalScale +
                          (_openController.value * (1.05 - normalScale));
                      opacity =
                          normalOpacity +
                          (_openController.value * (1.0 - normalOpacity));
                    } else if (isAnyTarget) {
                      opacity =
                          normalOpacity * (1.0 - _openController.value * 0.6);
                    }

                    final gradient = _getGradientForType(wallet.type);

                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Transform.translate(
                        offset: Offset(0, offsetY),
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.bottomCenter,
                          child: Opacity(
                            opacity: opacity.clamp(0.0, 1.0),
                            child: GestureDetector(
                              onTap: () => _handleCardTap(index, wallet.id),
                              child: Hero(
                                tag: 'wallet_card_${wallet.id}',
                                child: Container(
                                  height: cardHeight,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: gradient.first.withValues(
                                          alpha: isTarget ? 0.4 : 0.15,
                                        ),
                                        blurRadius: isTarget ? 16 : 8,
                                        offset: Offset(0, isTarget ? 8 : 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: gradient,
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 16,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      wallet.name,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    formatCurrency.format(
                                                      wallet.balance,
                                                    ),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      wallet.type.toUpperCase(),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Opacity(
                      opacity: (_animatingIndex != null)
                          ? (1.0 - _openController.value * 0.6).clamp(0.4, 1.0)
                          : 1.0,
                      child: Container(
                        height: cardHeight,
                        decoration: BoxDecoration(
                           borderRadius: BorderRadius.circular(24),
                           boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4364F7).withValues(alpha: 0.25),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF0052D4),
                                        Color(0xFF4364F7),
                                        Color(0xFF6FB1FC),
                                      ],
                                      stops: [0.0, 0.6, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'home.total_balance_label'
                                              .tr()
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w400,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      formatCurrency.format(totalBalance),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'IN +${_formatAbbreviated(widget.monthlyIncome)}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'OUT -${_formatAbbreviated(widget.monthlyExpense)}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
