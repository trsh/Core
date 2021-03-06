package sx.input;

import sx.backend.Point;
import sx.signals.GlobalPointerSignal;
import sx.widgets.Widget;
import sx.signals.Signal;

using sx.tools.WidgetTools;


/**
 * :TODO:
 * Replace Array with linked list to avoid garbage collection.
 */
typedef OrderedList<T> = Array<T>;


/**
 * Manages pointers events (like mouse and touch)
 *
 * Global pointer signals `onNextRelease`, `onNextPress`, `onNextMove` are one-time signals: once dispatched all current listeners will be removed.
 */
@:access(sx.widgets.Widget)
class Pointer
{
    /** Dispatched on each release of mouse button or each touch end. */
    static public var onNextRelease (get,never) : GlobalPointerSignal;
    static private var __onNextRelease : GlobalPointerSignal;
    /** Dispatched on each press of mouse button or each touch begin. */
    static public var onNextPress (get,never) : GlobalPointerSignal;
    static private var __onNextPress : GlobalPointerSignal;
    /** Dispatched on each mouse move or touch move. */
    static public var onNextMove (get,never) : GlobalPointerSignal;
    static private var __onNextMove : GlobalPointerSignal;

    /** Dispatched on each release of mouse button or each touch end. */
    static public var onRelease (get,never) : GlobalPointerSignal;
    static private var __onRelease : GlobalPointerSignal;
    /** Dispatched on each press of mouse button or each touch begin. */
    static public var onPress (get,never) : GlobalPointerSignal;
    static private var __onPress : GlobalPointerSignal;
    /** Dispatched on each mouse move or touch move. */
    static public var onMove (get,never) : GlobalPointerSignal;
    static private var __onMove : GlobalPointerSignal;

    /** Flag used to stop signal bubbling */
    static private var __currentSignalStopped : Bool = false;
    /** Widgets currently pressed */
    static private var __pressedWidgets : OrderedList<Widget> = new OrderedList();
    /** Widgets which were under the pointer at the moment of last pointer event */
    static private var __hoveredWidgets : OrderedList<Widget> = new OrderedList();
    /** Current touchId for mouse */
    static private var __mouseTouchId : Int = 0;
    /** Counter used to generate touchId for mouse events */
    static private var __touchIdCounter : Int = -100;


    /**
     * Get pointer global position (mouse cursor or touch with specified `touchId`).
     *
     * If `touchId` is less or equal to `0` it should return mouse position or first touch position.
     *
     * Measured in pixels.
     */
    static public function getPosition (touchId:Int = 0) : Point
    {
        return Sx.backendManager.getPointerPosition(touchId);
    }


    /**
     * Should be called by backend when user pressed mouse button or started touch interaction.
     */
    static public function pressed (widget:Null<Widget>, touchId:Int = 0) : Void
    {
        if (widget != null) widget = widget.findEnabled();

        //no touchId? Generate one
        if (touchId == 0) {
            __mouseTouchId = __touchIdCounter--;
            touchId = __mouseTouchId;
        }

        if (__onNextPress != null) {
            var old = __onNextPress;
            __onNextPress = null;
            old.dispatch(widget, touchId);
        }
        __onPress.dispatch(widget, touchId);

        if (!__currentSignalStopped) {
            __dispatchOnPointerPress(widget, touchId);
        }
        __currentSignalStopped = false;
    }


    /**
     * Should be called by backend when user released mouse button or ended touch.
     */
    static public function released (widget:Null<Widget>, touchId:Int = 0) : Void
    {
        if (widget != null) widget = widget.findEnabled();

        //no touchId? Use generated one
        if (touchId == 0) {
            touchId = __mouseTouchId;
            __mouseTouchId = 0;
        }

        if (__onNextRelease != null) {
            var old = __onNextRelease;
            __onNextRelease = null;
            old.dispatch(widget, touchId);
        }
        __onRelease.dispatch(widget, touchId);

        if (!__currentSignalStopped) {
            __dispatchOnPointerRelease(widget, touchId);
            __dispatchOnPointerTap(widget, touchId);
        }
        __currentSignalStopped = false;
    }


    /**
     * Should be called by backend when user moved pointer.
     */
    static public function moved (widget:Null<Widget>, touchId:Int = 0) : Void
    {
        if (widget != null) widget = widget.findEnabled();
        if (touchId == 0) touchId = __mouseTouchId;

        if (__onNextMove != null) {
            var old = __onNextMove;
            __onNextMove = null;
            old.dispatch(widget, touchId);
        }
        __onMove.dispatch(widget, touchId);

        if (__currentSignalStopped) {
            __currentSignalStopped = false;
            return;
        }

        //No widgets under cursor. Just dispatch `PointerOut` signal if needed
        if (widget == null) {
            if (__hoveredWidgets.length > 0) {
                __dispatchOnPointerOut(__hoveredWidgets, null, touchId);
                __hoveredWidgets = new OrderedList();
            }

        //Has some widgets under cursor. Dispatch all required signals
        } else {
            var newHovered = __collectHoveredWidgets(widget);

            __dispatchOnPointerOut(__hoveredWidgets, newHovered, touchId);
            __dispatchOnPointerOver(__hoveredWidgets, newHovered, touchId);
            __dispatchOnPointerMove(widget, touchId);

            __hoveredWidgets = newHovered;
        }

        __currentSignalStopped = false;
    }


    /**
     * Stop bubbling current signal
     */
    static public function stopCurrentSignal () : Void
    {
        __currentSignalStopped = true;
    }


    /**
     * Dispatch `onPointerOut` on all widgets are currently hovered
     */
    static public function forcePointerOut (touchId:Int) : Void
    {
        var newHovered = new OrderedList();
        __dispatchOnPointerOut(__hoveredWidgets, newHovered, touchId);
        __hoveredWidgets = newHovered;
    }


    /**
     * Collect list of widgets currently under pointer
     */
    static private inline function __collectHoveredWidgets (start:Widget) : OrderedList<Widget>
    {
        var hovered = new OrderedList<Widget>();

        var processor = start;
        while (processor != null) {
            hovered.push(processor);
            processor = processor.parent;
        }

        return hovered;
    }


    /**
     * Dispatch `onPointerPress`
     */
    static private inline function __dispatchOnPointerPress (dispatcher:Widget, touchId:Int) : Void
    {
        __currentSignalStopped = false;
        var processor = dispatcher;
        while (processor != null && !__currentSignalStopped) {
            processor.__onPointerPress.dispatch(processor, dispatcher, touchId);

            if (__pressedWidgets.indexOf(processor) < 0) {
                __pressedWidgets.push(processor);
            }

            processor = processor.parent;
        }
    }


    /**
     * Dispatch `onPointerRelease`
     */
    static private inline function __dispatchOnPointerRelease (dispatcher:Widget, touchId:Int) : Void
    {
        __currentSignalStopped = false;
        var processor = dispatcher;
        while (processor != null && !__currentSignalStopped) {
            processor.__onPointerRelease.dispatch(processor, dispatcher, touchId);
            processor = processor.parent;
        }
    }


    /**
     * Dispatch `onPointerTap`
     */
    static private inline function __dispatchOnPointerTap (dispatcher:Widget, touchId:Int) : Void
    {
        if (__pressedWidgets.length > 0) {
            __currentSignalStopped = false;
            var processor = dispatcher;
            while (processor != null && !__currentSignalStopped) {
                if (__pressedWidgets.indexOf(processor) >= 0) {
                    processor.__onPointerTap.dispatch(processor, dispatcher, touchId);
                }
                processor = processor.parent;
            }

            __pressedWidgets = new OrderedList();
        }
    }


    /**
     * Dispatch `onPointerOut`
     */
    static private inline function __dispatchOnPointerOut (wasHovered:OrderedList<Widget>, nowHovered:Null<OrderedList<Widget>>, touchId:Int) : Void
    {
        if (wasHovered.length > 0) {
            __currentSignalStopped = false;
            for (w in wasHovered) {
                if ((nowHovered == null || nowHovered.indexOf(w) < 0) && w.enabled) {
                    w.__onPointerOut.dispatch(w, w, touchId);
                    if (__currentSignalStopped) break;
                }
            }
        }
    }


    /**
     * Dispatch `onPointerOver`
     */
    static private inline function __dispatchOnPointerOver (oldHovered:OrderedList<Widget>, nowHovered:OrderedList<Widget>, touchId:Int) : Void
    {
        if (nowHovered.length > 0) {
            __currentSignalStopped = false;
            for (w in nowHovered) {
                if (oldHovered.indexOf(w) < 0) {
                    w.__onPointerOver.dispatch(w, w, touchId);
                    if (__currentSignalStopped) break;
                }
            }
        }
    }


    /**
     * Dispatch `onPointerMove`
     */
    static private inline function __dispatchOnPointerMove (dispatcher:Widget, touchId:Int) : Void
    {
        __currentSignalStopped = false;
        var processor = dispatcher;
        while (processor != null && !__currentSignalStopped) {
            processor.__onPointerMove.dispatch(processor, dispatcher, touchId);
            processor = processor.parent;
        }
    }


    /** Typical signal getters */
    static private function get_onNextPress ()            return (__onNextPress == null ? __onNextPress = new Signal() : __onNextPress);
    static private function get_onNextRelease ()          return (__onNextRelease == null ? __onNextRelease = new Signal() : __onNextRelease);
    static private function get_onNextMove ()             return (__onNextMove == null ? __onNextMove = new Signal() : __onNextMove);
    static private function get_onPress ()                return (__onPress == null ? __onPress = new Signal() : __onPress);
    static private function get_onRelease ()              return (__onRelease == null ? __onRelease = new Signal() : __onRelease);
    static private function get_onMove ()                 return (__onMove == null ? __onMove = new Signal() : __onMove);


    /**
     * Constructor
     */
    private function new () : Void
    {

    }

}//class Pointer