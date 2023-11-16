type t

type orientation = [#vertical | #horizontal]
type labelPos = [#left(float) | #center | #right(float)]

let displayBBox: t => bool
let setDisplayBBox: (t, bool) => unit

let setOrientation: (t, orientation) => unit

let setNode: (t, string, float, float) => unit
let setEdge: (t, string, string, option<string>, float, float, labelPos) => unit

let processNodes: (t, (string, Diagram__Dagre.nodeInfo) => unit) => unit
let processEdges: (t, (string, Diagram__Dagre.edgeInfo) => unit) => unit

let run: (t, Dom.element) => unit
let reset: t => unit
let registerListener: (t, unit => unit) => unit
let onUpdate: t => unit

let make: (~nodeSep: int, ~edgeSep: int, ~rankSep: int) => t

@set external attach: (Dom.element, t) => unit = "layout"
@get external get: Dom.element => t = "layout"
