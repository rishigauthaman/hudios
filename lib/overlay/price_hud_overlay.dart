import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/overlay_position.dart';
import '../models/price_model.dart';
import '../providers/app_providers.dart';
import '../utils/formatters.dart';

class PriceHudOverlay extends ConsumerStatefulWidget {
  const PriceHudOverlay({required this.onOpenSettings, super.key});

  final VoidCallback onOpenSettings;

  @override
  ConsumerState<PriceHudOverlay> createState() => _PriceHudOverlayState();
}

class _PriceHudOverlayState extends ConsumerState<PriceHudOverlay> {
  static const _edgePadding = 12.0;

  late Offset _position;
  var _expanded = false;
  var _dragging = false;

  @override
  void initState() {
    super.initState();
    final stored = ref.read(settingsRepositoryProvider).loadOverlayPosition();
    _position = Offset(stored.dx, stored.dy);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final price = ref.watch(livePriceProvider);
    final size = _overlaySize(settings);
    final isCircle = settings.widgetLayout == OverlayWidgetLayout.circle;
    final overlayColor = Color(settings.overlayColorValue);
    final textColor = overlayColor.computeLuminance() > 0.55
        ? const Color(0xFF0B0F14)
        : Colors.white;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onTap: () => setState(() => _expanded = true),
        onDoubleTap: () => setState(() => _expanded = false),
        onLongPress: widget.onOpenSettings,
        onPanStart: (_) {
          if (!settings.lockPosition) {
            setState(() => _dragging = true);
          }
        },
        onPanUpdate: (details) => _move(details.delta, size),
        onPanEnd: (_) => _savePosition(size),
        child: AnimatedScale(
          scale: _dragging ? 1.04 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            width: size.width,
            height: size.height,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: overlayColor.withValues(
                alpha: (1 - settings.backgroundTransparency)
                    .clamp(0.08, 1)
                    .toDouble(),
              ),
              shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircle
                  ? null
                  : BorderRadius.circular(
                      settings.widgetLayout == OverlayWidgetLayout.pill
                          ? settings.cornerRadius
                          : settings.cornerRadius.clamp(4, 22).toDouble(),
                    ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: price.when(
              data: (value) => _PriceContent(
                price: value,
                expanded: _expanded,
                textSize: settings.textSize,
                widgetScale: settings.widgetScale,
                widgetLayout: settings.widgetLayout,
                cornerRadius: settings.cornerRadius,
                textColor: textColor,
                flashEnabled: settings.priceFlashEnabled,
                showDecimals: settings.showDecimals,
                onCollapse: () => setState(() => _expanded = false),
                onSettings: widget.onOpenSettings,
              ),
              loading: () => const Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    'Price unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _move(Offset delta, Size size) {
    if (ref.read(appSettingsProvider).lockPosition) {
      return;
    }

    final bounds = MediaQuery.sizeOf(context);
    setState(() {
      _position = Offset(
        (_position.dx + delta.dx)
            .clamp(_edgePadding, bounds.width - size.width - _edgePadding)
            .toDouble(),
        (_position.dy + delta.dy)
            .clamp(_edgePadding, bounds.height - size.height - _edgePadding)
            .toDouble(),
      );
    });
  }

  Future<void> _savePosition(Size size) async {
    final bounds = MediaQuery.sizeOf(context);
    setState(() {
      _dragging = false;
      _position = Offset(
        _position.dx
            .clamp(_edgePadding, bounds.width - size.width - _edgePadding)
            .toDouble(),
        _position.dy
            .clamp(_edgePadding, bounds.height - size.height - _edgePadding)
            .toDouble(),
      );
    });

    await ref
        .read(settingsRepositoryProvider)
        .saveOverlayPosition(
          OverlayPosition(dx: _position.dx, dy: _position.dy),
        );
  }

  Size _overlaySize(AppSettings settings) {
    final scale = settings.widgetScale.clamp(0.75, 1.6).toDouble();
    if (settings.widgetLayout != OverlayWidgetLayout.pill) {
      final side = 96 * scale;
      return Size(side, side);
    }
    return _expanded
        ? Size(220 * scale, 168 * scale)
        : Size(132 * scale, 72 * scale);
  }
}

class _PriceContent extends StatefulWidget {
  const _PriceContent({
    required this.price,
    required this.expanded,
    required this.textSize,
    required this.widgetScale,
    required this.widgetLayout,
    required this.cornerRadius,
    required this.textColor,
    required this.flashEnabled,
    required this.showDecimals,
    required this.onCollapse,
    required this.onSettings,
  });

  final PriceModel price;
  final bool expanded;
  final double textSize;
  final double widgetScale;
  final OverlayWidgetLayout widgetLayout;
  final double cornerRadius;
  final Color textColor;
  final bool flashEnabled;
  final bool showDecimals;
  final VoidCallback onCollapse;
  final VoidCallback onSettings;

  @override
  State<_PriceContent> createState() => _PriceContentState();
}

class _PriceContentState extends State<_PriceContent> {
  Color _flashColor = Colors.transparent;

  @override
  void didUpdateWidget(covariant _PriceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.price.price == widget.price.price) {
      return;
    }

    if (!widget.flashEnabled) {
      _flashColor = Colors.transparent;
      return;
    }

    _flashColor = widget.price.isUp
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted) {
        setState(() => _flashColor = Colors.transparent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final priceText = Formatters.compactPrice(
      widget.price.price,
      showDecimals: widget.showDecimals,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _flashColor.withValues(alpha: 0.22),
        shape: widget.widgetLayout == OverlayWidgetLayout.circle
            ? BoxShape.circle
            : BoxShape.rectangle,
        borderRadius: widget.widgetLayout == OverlayWidgetLayout.circle
            ? null
            : BorderRadius.circular(widget.cornerRadius),
      ),
      padding: EdgeInsets.all((widget.expanded ? 14 : 10) * _scale),
      child: widget.expanded && widget.widgetLayout == OverlayWidgetLayout.pill
          ? _expanded(priceText)
          : _collapsed(priceText),
    );
  }

  Widget _collapsed(String priceText) {
    final compact = widget.widgetLayout != OverlayWidgetLayout.pill;
    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _compactSymbol(widget.price.symbol),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: widget.textColor.withValues(alpha: 0.82),
            fontSize: (compact ? 12 : 13) * _scale,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: Text(
            priceText,
            key: ValueKey(priceText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: widget.textColor,
              fontSize: (widget.textSize * _scale * (compact ? 0.9 : 1))
                  .clamp(10, 34)
                  .toDouble(),
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _expanded(String priceText) {
    final direction = widget.price.isDown ? 'DOWN' : 'UP';
    final directionColor = widget.flashEnabled
        ? (widget.price.isDown
              ? const Color(0xFFF87171)
              : const Color(0xFF4ADE80))
        : widget.textColor.withValues(alpha: 0.72);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.price.symbol,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.textColor.withValues(alpha: 0.82),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Close',
              visualDensity: VisualDensity.compact,
              color: widget.textColor.withValues(alpha: 0.78),
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onCollapse,
            ),
          ],
        ),
        Text(
          priceText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: widget.textColor,
            fontSize: widget.textSize.clamp(18, 28),
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$direction ${widget.price.percentChange.toStringAsFixed(2)}%',
          style: TextStyle(
            color: directionColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: Text(
                _lastUpdatedLabel(widget.price.updatedAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.textColor.withValues(alpha: 0.56),
                  fontSize: 11,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              visualDensity: VisualDensity.compact,
              color: widget.textColor.withValues(alpha: 0.78),
              icon: const Icon(Icons.settings_outlined, size: 18),
              onPressed: widget.onSettings,
            ),
          ],
        ),
      ],
    );
  }

  String _compactSymbol(String symbol) {
    if (symbol.endsWith('USDT')) {
      return symbol.substring(0, symbol.length - 4);
    }
    return symbol;
  }

  String _lastUpdatedLabel(DateTime updatedAt) {
    final time = TimeOfDay.fromDateTime(updatedAt);
    return 'Updated ${time.format(context)}';
  }

  double get _scale => widget.widgetScale.clamp(0.75, 1.6).toDouble();
}
