package sx.widgets;

import sx.backend.BitmapData;
import sx.backend.BitmapRenderer;
import sx.properties.metric.Size;
import sx.properties.metric.Units;
import sx.widgets.base.RendererHolder;
import sx.properties.Orientation;

using sx.tools.PropertiesTools;



/**
 * Bitmaps
 *
 */
class Bmp extends RendererHolder
{
    /** Bitmap data to render */
    public var bitmapData (default,set) : Null<BitmapData>;
    /** Bitmap renderer */
    public var renderer (default,null) : BitmapRenderer;
    /**
     * If `autoSize` is disabled, rendered bitmap will be stretched to `Bmp` widget size.
     * This option indicates if scaled bitmap should keep original aspect ratio.
     *
     * If both `autoSize.width` and `autoSize.height` are `true`, then `keepAspect` is ignored.
     * If `autoSize.width` is `false` and `autoSize.height` is `true` and `keepAspect` is `false` then bitmap width is stretched.
     * If `autoSize.width` is `true` and `autoSize.height` is `false` and `keepAspect` is `false` then bitmap height is stretched.
     * If both `autoSize.width` and `autoSize.height` are `false` and `keepAspect` is `false`, then bitmap width and height are stretched.
     * If both `autoSize.width` and `autoSize.height` are `false` and `keepAspect` is `true`, then one of bitmap width or height
     *      is stretched, while another one is scaled according to original bitmap aspect ratio.
     */
    public var keepAspect (default,set) : Bool = true;
    /** Should we use smoothing? */
    public var smooth (default,set) : Bool = false;

    /** To prevent multiple sequential `__updateBitmapScaling` */
    private var __dontUpdateBitmapScaling : Bool = false;


    /**
     * Creates renderer instance
     */
    override private function __createRenderer () : Void
    {
        renderer = Sx.backendManager.bitmapRenderer(this);
    }


    /**
     * Called when `width` or `height` is changed.
     */
    override private function __propertyResized (changed:Size, previousUnits:Units, previousValue:Float) : Void
    {
        if (__dontUpdateBitmapScaling) {
            super.__propertyResized(changed, previousUnits, previousValue);
        } else {
            __dontUpdateBitmapScaling = true;
            super.__propertyResized(changed, previousUnits, previousValue);
            __updateBitmapScaling();
            __dontUpdateBitmapScaling = false;
        }
    }


    /**
     * Called when `padding` changed
     */
    override private function __paddingChanged (horizontal:Bool, vertical:Bool) : Void
    {
        if (__dontUpdateBitmapScaling) {
            super.__paddingChanged(horizontal, vertical);
        } else {
            __dontUpdateBitmapScaling = true;
            __updateBitmapScaling();
            super.__paddingChanged(horizontal, vertical);
            __dontUpdateBitmapScaling = false;
        }
    }


    /**
     * Called when `autoSize` settings changed
     */
    override private function __autoSizeChanged (widthChanged:Bool, heightChanged:Bool) : Void
    {
        if (__dontUpdateBitmapScaling) {
            super.__paddingChanged(widthChanged, heightChanged);
        } else {
            __dontUpdateBitmapScaling = true;
            __updateBitmapScaling();
            super.__paddingChanged(widthChanged, heightChanged);
            __dontUpdateBitmapScaling = false;
        }
    }


    /**
     * Pass correct bitmap scaling to renderer
     */
    private inline function __updateBitmapScaling () : Void
    {
        if (autoSize.both()) {
            renderer.setBitmapScale(1, 1);
        } else if (autoSize.width) {
            __scaleBitmapHeight();
        } else if (autoSize.height) {
            __scaleBitmapWidth();
        } else {
            __scaleBitmapBoth();
        }
    }


    /**
     * Scale bitmap height while width left unscaled.
     */
    private inline function __scaleBitmapHeight () : Void
    {
        var bitmapHeight = renderer.getBitmapDataHeight();

        if (bitmapHeight <= 0) {
            renderer.setBitmapScale(0, 0);

        } else {
            if (keepAspect) {
                renderer.setBitmapScale(1, 1);

            } else {
                var renderHeight = height.px - padding.sumPx(Vertical);
                if (renderHeight <= 0) {
                    renderer.setBitmapScale(0, 0);
                } else {
                    var scaleY = renderHeight / bitmapHeight;
                    renderer.setBitmapScale(1, scaleY);
                }
            }
        }
    }


    /**
     * Scale bitmap width while height left unscaled.
     */
    private inline function __scaleBitmapWidth () : Void
    {
        var bitmapWidth = renderer.getBitmapDataWidth();

        if (bitmapWidth <= 0) {
            renderer.setBitmapScale(0, 0);

        } else {
            if (keepAspect) {
                renderer.setBitmapScale(1, 1);

            } else {
                var renderWidth = width.px - padding.sumPx(Horizontal);
                if (renderWidth <= 0) {
                    renderer.setBitmapScale(0, 0);
                } else {
                    var scaleX = renderWidth / bitmapWidth;
                    renderer.setBitmapScale(scaleX, 1);
                }
            }
        }
    }


    /**
     * Scale both width and height of bitmap
     */
    private inline function __scaleBitmapBoth () : Void
    {
        var bitmapWidth  = renderer.getBitmapDataWidth();
        var bitmapHeight = renderer.getBitmapDataHeight();

        if (bitmapWidth <= 0 || bitmapHeight <= 0) {
            renderer.setBitmapScale(0, 0);

        } else {
            var renderWidth  = width.px - padding.left.px - padding.right.px;
            var renderHeight = height.px - padding.top.px - padding.bottom.px;

            if (renderWidth <= 0 || renderHeight <= 0) {
                renderer.setBitmapScale(0, 0);

            } else {
                var scaleX = renderWidth / bitmapWidth;
                var scaleY = renderHeight / bitmapHeight;

                if (keepAspect) {
                    if (scaleX < scaleY) {
                        renderer.setBitmapScale(scaleX, scaleX);
                    } else {
                        renderer.setBitmapScale(scaleY, scaleY);
                    }
                } else {
                    renderer.setBitmapScale(scaleX, scaleY);
                }
            }
        }
    }


    /**
     * Setter `bitmapData`
     */
    private function set_bitmapData (value:BitmapData) : BitmapData
    {
        bitmapData = value;
        renderer.setBitmapData(bitmapData);

        return value;
    }


    /**
     * Setter `keepAspect`
     */
    private function set_keepAspect (value:Bool) : Bool
    {
        if (keepAspect != value) {
            keepAspect = value;
            __updateBitmapScaling();
        }

        return value;
    }


    /**
     * Setter `smooth`
     */
    private function set_smooth (value:Bool) : Bool
    {
        if (smooth != value) {
            smooth = value;
            renderer.setBitmapSmoothing(smooth);
        }

        return value;
    }


    /** Getters */
    override private function get___renderer () return renderer;

}//class Bmp