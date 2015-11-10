package sx.widgets;

import sx.backend.Point;
import sx.input.Pointer;
import sx.properties.Orientation;
import sx.Sx;
import sx.tween.Actuator;
import sx.tween.Tweener;

using sx.Sx;


/**
 * Scroll container.
 *
 * Content scrolled by changing children coordinates.
 */
class Scroll extends Widget
{
    /** If pointer moved by this amount of DIPs after user started interaction, then we treat this interaction as scrolling */
    static public inline var START_SCROLL_MOVE = 4;

    /**
     * Indicates if user is currently dragging scrolled content.
     * Assign `false` to stop dragging.
     * Assigning `true` while no real dragging is happening has no effect and `dragging` will stay `false`.
     */
    public var dragging (get,set) : Bool;
    private var __dragging : Bool = false;
    /**
     * Indicates if content is currently dragged or scrolled by inertia.
     * Assign `false` to stop scrolling.
     * Assigning `true` while no real scrolling is happening has no effect and `scrolling` will stay `false`.
     */
    public var scrolling (get,set) : Bool;
    private var __scrolling : Bool = false;
    /** Enable/disable vertical scrolling */
    public var verticalScroll : Bool = true;
    /** Enable/disable horizontal scrolling */
    public var horizontalScroll : Bool = true;
    /** Last registered coordinates of contact with pointer */
    private var __lastContact : Point;
    /** Time of `__lastContact` */
    private var __lastTime : Float = 0;
    /** Previous registered coordinates of contact with pointer */
    private var __previousContact : Point;
    /** Time of `__previousContact` */
    private var __previousTime : Float = 0;
    /** Description */
    private var __velocitiesX : Array<Float>;
    private var __velocitiesY : Array<Float>;
    /** Id of a touch event which started dragging content */
    private var __dragTouchId : Int = 0;
    /** Last scroll actuator */
    private var __scrollActuator : Actuator;

    /** If user started interaction, but are still not sure whether he wants to scroll or not. */
    private var __waitingForScroll : Bool = false;


    /**
     * Constructor
     */
    public function new () : Void
    {
        super();
        overflow = false;

        onPointerPress.add(__onInteractionStarted);
    }


    /**
     * Scroll by specified amount of DIPs
     */
    public function scrollBy (dX:Float, dY:Float) : Void
    {
        var minX = 0.0;
        var maxX = 0.0;
        var minY = 0.0;
        var maxY = 0.0;

        var child : Widget;
        var left,top;
        for (i in 0...numChildren) {
            child = getChildAt(i);
            left  = child.left.dip;
            top   = child.top.dip;

            if (i == 0 || left < minX) {
                minX = left;
            }
            if (i == 0 || left + child.width.dip > maxX) {
                maxX = left + child.width.dip;
            }
            if (i == 0 || top < minY) {
                minY = top;
            }
            if (i == 0 || top + child.height.dip > maxY) {
                maxY = top + child.height.dip;
            }
        }

        var contentWidth  = maxX - minX;
        var contentHeight = maxY - minY;

        var horizontal = (horizontalScroll && dX != 0 && contentWidth > width.dip);
        var vertical   = (verticalScroll && dY != 0 && contentHeight > height.dip);

        if (horizontal) {
            if (minX + dX > 0) {
                dX = -minX;
            } else if (maxX + dX < width.dip) {
                dX = width.dip - maxX;
            }
        }

        if (vertical) {
            if (minY + dY > 0) {
                dY = -minY;
            } else if (maxY + dY < height.dip) {
                dY = height.dip - maxY;
            }
        }

        for (i in 0...numChildren) {
            child = getChildAt(i);
            if (horizontal) child.left.dip += dX;
            if (vertical) child.top.dip += dY;
        }
    }


    /**
     * Method to cleanup and release this object for garbage collector.
     */
    override public function dispose (disposeChildren:Bool = true) : Void
    {
        if (__waitingForScroll) {
            __stopWaitingForScroll(null, __dragTouchId);
        }
        if (__scrolling) {
            __stopScrolling();
        }

        super.dispose();
    }


    /**
     * Waits for user interaction
     */
    private function __onInteractionStarted (me:Widget, dispatcher:Widget, touchId:Int) : Void
    {
        if (__waitingForScroll || __dragging) return;

        Pointer.stopCurrentSignal();
        __waitingForScroll = true;

        if (__scrolling) {
            __stopScrolling();
        }

        __dragTouchId = touchId;
        __lastContact = globalToLocal(Pointer.getPosition(touchId));
        __lastTime = Tweener.getTime();

        Pointer.onMove.add(__waitForScrollMove);
        Pointer.onNextRelease.add(__stopWaitingForScroll);
    }


    /**
     * Called on every frame till user starts or cancels scrolling
     */
    private function __waitForScrollMove (dispatcher:Null<Widget>, touchId:Int) : Void
    {
        if (__dragTouchId != touchId) return;

        Pointer.stopCurrentSignal();

        var pos = globalToLocal(Pointer.getPosition(touchId));

        var dX = pos.x - __lastContact.x;
        var dY = pos.y - __lastContact.y;
        if (Math.abs(dX) >= START_SCROLL_MOVE || Math.abs(dY) >= START_SCROLL_MOVE) {
            __stopWaitingForScroll(null, __dragTouchId);
            Pointer.forcePointerOut(__dragTouchId);
            Pointer.released(null, __dragTouchId);
            __startDrag();
        }
    }


    /**
     * Description
     */
    private function __stopWaitingForScroll (dispatcher:Null<Widget>, touchId:Int) : Void
    {
        if (__dragTouchId != touchId) return;

        __waitingForScroll = false;

        Pointer.onMove.remove(__waitForScrollMove);
    }


    /**
     * Start scrolling on press
     */
    private function __startDrag () : Void
    {
        __scrolling = true;
        __dragging  = true;

        __velocitiesX     = [];
        __velocitiesY     = [];
        __lastContact     = null;
        __previousContact = null;
        __updateDrag();

        Sx.onFrame.add(__updateDrag);
        Pointer.onMove.add(__stopPointerMoveSignalWhileDragging);
        Pointer.onNextRelease.add(__pointerReleasedWhileDragging);
    }


    /**
     * Description
     */
    private function __stopPointerMoveSignalWhileDragging (dispatcher:Null<Widget>, touchId:Int) : Void
    {
        if (touchId != __dragTouchId) return;
        Pointer.stopCurrentSignal();
    }


    /**
     * Collect dragging info on each frame
     */
    private function __updateDrag () : Void
    {
        if (Tweener.pausedAll) return;

        Pointer.stopCurrentSignal();

        __previousTime    = __lastTime;
        __lastTime        = Tweener.getTime();
        __previousContact = __lastContact;
        __lastContact = globalToLocal(Pointer.getPosition(__dragTouchId));

        if (__previousContact != null) {
            var dX = __lastContact.x - __previousContact.x;
            var dY = __lastContact.y - __previousContact.y;
            dX = dX.toDip();
            dY = dY.toDip();
            scrollBy(dX, dY);

            var dTime = __lastTime - __previousTime;
            if (dTime != 0) {
                var vX = (__lastContact.x - __previousContact.x) / dTime;
                var vY = (__lastContact.y - __previousContact.y) / dTime;
                __velocitiesX.push(vX);
                __velocitiesY.push(vY);
                if (__velocitiesX.length > 3) __velocitiesX.shift();
                if (__velocitiesY.length > 3) __velocitiesY.shift();
            }
        }
    }


    /**
     * User stopped dragging scrolled content
     */
    private function __pointerReleasedWhileDragging (dispatcher:Null<Widget>, touchId:Int) : Void
    {
        if (__dragTouchId != touchId || !__dragging) return;

        Pointer.stopCurrentSignal();

        __stopDragging();
    }


    /**
     * Stop dragging scrolled content
     */
    private function __stopDragging () : Void
    {
        __dragging = false;
        Sx.onFrame.remove(__updateDrag);
        Pointer.onMove.remove(__stopPointerMoveSignalWhileDragging);

        if (__velocitiesX.length == 0 || __velocitiesY.length == 0) {
            return;
        }

        var vX = __averageVelocity(__velocitiesX);
        var vY = __averageVelocity(__velocitiesY);

        var time = Tweener.getTime();
        __scrollActuator = tween.expoOut(2, vX = 0, vY = 0).onComplete(__stopScrolling).onUpdate(function() {
            var dTime = Tweener.getTime() - time;
            var dX = vX * dTime;
            var dY = vY * dTime;
            time += dTime;
            scrollBy(dX.toDip(), dY.toDip());
        });
    }


    /**
     * Scrolling finished or should be stopped
     */
    private function __stopScrolling () : Void
    {
        if (__dragging) {
            __stopDragging();
        }

        if (__scrollActuator != null) {
            if (!__scrollActuator.done) {
                __scrollActuator.stop();
            }
            __scrollActuator = null;
        }
        __scrolling = false;
    }


    /**
     * Setter `dragging`
     */
    private function set_dragging (value:Bool) : Bool
    {
        if (__dragging && !value) {
            __stopDragging();
        }

        return value;
    }


    /**
     * Setter `scrolling`
     */
    private function set_scrolling (value:Bool) : Bool
    {
        if (__scrolling && !value) {
            __stopScrolling();
        }

        return value;
    }


    /** Getters */
    private function get_dragging ()        return __dragging;
    private function get_scrolling ()       return __scrolling;


    /**
     * Calculate average velocity
     */
    static private function __averageVelocity (velocities:Array<Float>) : Float
    {
        var v = velocities[0];
        for (i in 1...velocities.length) {
            v += velocities[i];
        }
        v /= velocities.length;

        return v;
    }

}//class Scroll