import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

extension WidgetToImage on Widget {
  /// Wraps the widget in a RepaintBoundary with the given GlobalKey.
  /// This removes the boilerplate of manually nesting RepaintBoundaries in your UI code!
  Widget toRepaintBoundary(GlobalKey key) {
    return RepaintBoundary(
      key: key,
      child: this,
    );
  }

  /// Renders the widget to an image entirely off-screen without adding it to the tree.
  /// Great for generating dynamic, shareable images in the background!
  Future<ui.Image> toImageOffscreen({
    Duration wait = const Duration(milliseconds: 20),
    Size? logicalSize,
    double pixelRatio = 3.0,
  }) async {
    final repaintBoundary = RenderRepaintBoundary();

    // Create a standalone render view attached to the primary dispatcher
    final renderView = RenderView(
      view: WidgetsBinding.instance.platformDispatcher.views.first,
      child: RenderPositionedBox(
          alignment: Alignment.center, child: repaintBoundary),
      configuration: ViewConfiguration(
        logicalConstraints:
            BoxConstraints.tight(logicalSize ?? const Size(800, 800)),
        devicePixelRatio: pixelRatio,
      ),
    );

    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();

    final buildOwner = BuildOwner(focusManager: FocusManager());
    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: this,
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    if (wait.inMilliseconds > 0) {
      await Future.delayed(wait);
    }

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();
    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    return repaintBoundary.toImage(pixelRatio: pixelRatio);
  }
}
