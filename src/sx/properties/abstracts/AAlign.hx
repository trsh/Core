package sx.properties.abstracts;

import sx.properties.Align;


/**
 * Abstract to be able to write boleans, `HorizontalAlign` and `VerticalAlign` directly to `Align` instances.
 * Also accepts expressions like `Top & Left`, `Right & Middle`.
 */
@:forward(horizontal,vertical,set,onChange)
abstract AAlign (Align) from Align to Align
{
    /** Object pool */
    static private var __pool : Array<WeakAlign> = [];


    /**
     * Create from HorizontalAlign
     */
    @:access(sx.properties.Align.weak)
    @:from static private function fromHorizontal (v:HorizontalAlign) : AAlign
    {
        var weakAlign = __pool.pop();
        if (weakAlign == null) weakAlign = new WeakAlign();
        weakAlign.weak = true;
        weakAlign.set(v, None);

        return weakAlign;
    }


    /**
     * Create from VerticalAlign
     */
    @:access(sx.properties.Align.weak)
    @:from static private function fromVertical (v:VerticalAlign) : AAlign
    {
        var weakAlign = __pool.pop();
        if (weakAlign == null) weakAlign = new WeakAlign();
        weakAlign.weak = true;
        weakAlign.set(None, v);

        return weakAlign;
    }

}//abstract AAlign



/**
 * For temporary instances used just to pass values to other instances
 *
 */
@:access(sx.properties.abstracts.AAlign.__pool)
private class WeakAlign extends Align
{

    /**
     * Constructor
     */
    public function new () : Void
    {
        super();
        onChange = null;
    }


    /**
     * Return to object pool
     */
    override public function dispose () : Void
    {
        AAlign.__pool.push(this);
        //to prevent adding to pool multiple times
        weak = false;
    }

}//class WeakAlign