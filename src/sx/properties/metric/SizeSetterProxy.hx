package sx.properties.metric;

import sx.exceptions.LockedPropertyException;
import sx.properties.Orientation;
import sx.properties.metric.Units;



/**
 * Mimics `Size` interface but only allows to write values. Reading is prohibited.
 *
 */
class SizeSetterProxy
{

    /** Device independent pixels */
    public var dip (never,set) : Float;
    /** Physical pixels */
    public var px (never,set) : Float;
    /** Percentage. Used if this size is calculated as a proportional part of some other value. */
    public var pct (never,set) : Float;

    /**
     * This handler is invoked every time size value is changed.
     * Accepts Size instance which is reporting changes now as an argument.
     *
     * @param   Size    Changed instance
     * @param   Units   Used Units used before this change
     * @param   Float   New value
     *
     * This property can be set one time only. Trying to change it will throw `sx.exceptions.LockedPropertyException`
     */
    @:noCompletion
    public var onSet (default,set) : Null<SizeSetterProxy->Units->Float->Void>;

    /** Orientation. E.g. for `left`,`right` and `width` it's horizontal. */
    private var __orientation : Orientation;


    /**
     * Constructor
     *
     */
    public function new (orientation:Orientation = Vertical) : Void
    {
        __orientation = orientation;
    }


    /**
     * Check if this size defines vertical dimension
     */
    public inline function isVertical () : Bool
    {
        return __orientation == Vertical;
    }


    /**
     * Check if this size defines horizontal dimension
     */
    public inline function isHorizontal () : Bool
    {
        return __orientation == Horizontal;
    }


    /**
     * Invokes `onSet()` if `onSet` is not null
     */
    private function __invokeOnSet (units:Units, value:Float) : Void
    {
        if (onSet != null) onSet(this, units, value);
    }


    /**
     * Setter `dip`
     *
     */
    private function set_dip (value:Float) : Float
    {
        __invokeOnSet(Dip, value);

        return value;
    }


    /**
     * Setter `px`
     *
     */
    private function set_px (value:Float) : Float
    {
        __invokeOnSet(Pixel, value);

        return value;
    }


    /**
     * Setter `pct`
     *
     */
    private function set_pct (value:Float) : Float
    {
        __invokeOnSet(Percent, value);

        return value;
    }


    /**
     * Setter `onSet`
     */
    private function set_onSet (value:SizeSetterProxy->Units->Float->Void) : SizeSetterProxy->Units->Float->Void
    {
        if (onSet != null) {
            throw new LockedPropertyException();
        }

        return onSet = value;
    }

}//class SizeSetterProxy