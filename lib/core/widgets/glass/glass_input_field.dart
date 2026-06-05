import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/liquid_glass_theme.dart';

// Fallback defaults when LiquidGlassTheme extension is not found.
const double _kDefaultBlurSigma = 12.0;
const double _kDefaultSurfaceOpacity = 0.65;
const Color _kDefaultBorderGlowColor = Color(0x4D4D8DFE);
const Color _kDefaultSurfaceTintColor = Color(0xFF161515);
const double _kDefaultInnerHighlightOpacity = 0.08;
const Duration _kDefaultAnimationDuration = Duration(milliseconds: 200);

/// A text input field with a glass surface background, glowing focus border,
/// and subtle blur.
///
/// Background uses 0.5x the theme's blur sigma for subtlety.
/// Focus state animates the border glow to full primary color opacity (200ms).
/// Error state renders the border glow in `colorScheme.error`.
/// Minimum height: 48dp for accessibility compliance.
///
/// Supports all standard TextField parameters: controller, hint, label, error,
/// obscure, prefix/suffix icons, keyboard type, onChanged, onEditingComplete.
class GlassInputField extends StatefulWidget {
  /// Optional text editing controller.
  final TextEditingController? controller;

  /// Hint text displayed when the field is empty.
  final String? hintText;

  /// Label text displayed above the field.
  final String? labelText;

  /// Error text displayed below the field. When non-null, the border glow
  /// transitions to `colorScheme.error`.
  final String? errorText;

  /// Whether to obscure the text (for passwords).
  final bool obscureText;

  /// The type of keyboard to display.
  final TextInputType? keyboardType;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the field (e.g. presses done).
  final VoidCallback? onEditingComplete;

  /// Widget displayed before the input text.
  final Widget? prefixIcon;

  /// Widget displayed after the input text.
  final Widget? suffixIcon;

  /// Optional list of text input formatters.
  final List<TextInputFormatter>? inputFormatters;

  const GlassInputField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.onEditingComplete,
    this.prefixIcon,
    this.suffixIcon,
    this.inputFormatters,
  });

  @override
  State<GlassInputField> createState() => _GlassInputFieldState();
}

class _GlassInputFieldState extends State<GlassInputField>
    with SingleTickerProviderStateMixin {
  late AnimationController _focusAnimationController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);

    _focusAnimationController = AnimationController(
      vsync: this,
      duration: _kDefaultAnimationDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use 200ms as specified in requirements for focus transition.
    _focusAnimationController.duration = const Duration(milliseconds: 200);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _focusAnimationController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _focusAnimationController.forward();
    } else {
      _focusAnimationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final glassTheme = LiquidGlassTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Resolve theme tokens.
    final baseBlurSigma =
        (glassTheme?.blurSigma ?? _kDefaultBlurSigma) * 0.5;
    final surfaceOpacity =
        glassTheme?.surfaceOpacity ?? _kDefaultSurfaceOpacity;
    final surfaceTintColor =
        glassTheme?.surfaceTintColor ?? _kDefaultSurfaceTintColor;
    final innerHighlightOpacity =
        glassTheme?.innerHighlightOpacity ?? _kDefaultInnerHighlightOpacity;
    final baseBorderGlowColor =
        glassTheme?.borderGlowColor ?? _kDefaultBorderGlowColor;

    // Determine border glow color based on error state.
    final bool hasError = widget.errorText != null;
    final Color targetGlowColor = hasError
        ? colorScheme.error
        : colorScheme.primary;

    // Accessibility adjustments.
    final bool isBoldText = MediaQuery.boldTextOf(context);
    final bool isHighContrast = MediaQuery.highContrastOf(context);
    final bool accessibleNavigation =
        MediaQuery.of(context).accessibleNavigation;

    var resolvedSurfaceOpacity = surfaceOpacity;
    var effectiveEnableBlur = true;

    if (isHighContrast) {
      resolvedSurfaceOpacity = 0.9;
      effectiveEnableBlur = false;
    }
    if (isBoldText) {
      resolvedSurfaceOpacity =
          (resolvedSurfaceOpacity + 0.15).clamp(0.0, 1.0);
    }
    if (accessibleNavigation) {
      resolvedSurfaceOpacity = 0.92;
      effectiveEnableBlur = false;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label text above the field.
        if (widget.labelText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Text(
              widget.labelText!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),

        // Glass input field.
        AnimatedBuilder(
          animation: _focusAnimationController,
          builder: (context, child) {
            // Interpolate border glow opacity based on focus state.
            final glowOpacity = _focusAnimationController.value;
            final borderColor = Color.lerp(
              baseBorderGlowColor,
              targetGlowColor,
              glowOpacity,
            )!;

            return _buildGlassSurface(
              context,
              borderColor: borderColor,
              blurSigma: baseBlurSigma,
              surfaceTintColor: surfaceTintColor,
              surfaceOpacity: resolvedSurfaceOpacity,
              innerHighlightOpacity: innerHighlightOpacity,
              enableBlur: effectiveEnableBlur,
              child: child!,
            );
          },
          child: _buildTextField(context, colorScheme, textTheme),
        ),

        // Error text below the field.
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              widget.errorText!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGlassSurface(
    BuildContext context, {
    required Color borderColor,
    required double blurSigma,
    required Color surfaceTintColor,
    required double surfaceOpacity,
    required double innerHighlightOpacity,
    required bool enableBlur,
    required Widget child,
  }) {
    const borderRadius = BorderRadius.all(Radius.circular(16));

    final decoration = BoxDecoration(
      color: surfaceTintColor.withValues(alpha: surfaceOpacity),
      borderRadius: borderRadius,
      border: Border.all(
        color: borderColor,
        width: 1.0,
      ),
    );

    final innerHighlight = Container(
      height: 1.0,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: innerHighlightOpacity),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
    );

    Widget surface = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Container(
        decoration: decoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            innerHighlight,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: child,
            ),
          ],
        ),
      ),
    );

    if (enableBlur) {
      surface = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
          ),
          child: surface,
        ),
      );
    }

    return RepaintBoundary(child: surface);
  }

  Widget _buildTextField(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onEditingComplete: widget.onEditingComplete,
      style: textTheme.bodyLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.suffixIcon,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 14,
        ),
        isDense: true,
      ),
    );
  }
}
