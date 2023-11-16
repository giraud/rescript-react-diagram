module Node = {
  @module("../../../src/interop/Diagram__NodeTypes") @react.component
  external make: (
    ~nodeId: string,
    ~className: string=?,
    ~children: React.element,
    ~onClick: ReactEvent.Mouse.t => unit=?,
  ) => React.element = "Node"
}

module Edge = {
  @module("../../../src/interop/Diagram__NodeTypes") @react.component
  external make: (
    ~source: string,
    ~target: string,
    ~className: string=?,
    ~label: string=?,
    ~labelPos: Diagram__Layout.labelPos=?,
    ~onClick: ReactEvent.Mouse.t => unit=?,
  ) => React.element = "Edge"
}

module Map = {
  @module("../../../src/interop/Diagram__NodeTypes") @react.component
  external make: (~className: string=?) => React.element = "Map"
}

// pointer events are not declared in React bindings, need a workaround until ReactScript is updated...
module WithPointerEvents = {
  type mouseEvent = ReactEvent.Mouse.t => unit

  @react.component
  let make = (
    ~onPointerDown: option<mouseEvent>=?,
    ~onPointerMove: option<mouseEvent>=?,
    ~onPointerUp: option<mouseEvent>=?,
    ~children,
  ) => {
    React.cloneElement(
      children,
      {"onPointerDown": onPointerDown, "onPointerMove": onPointerMove, "onPointerUp": onPointerUp},
    )
  }
}

type commands = {reset: unit => unit, fitToView: unit => unit}
type refCommands = React.ref<option<commands>>

let fitToView = (cmd: refCommands) => cmd.current->Belt.Option.forEach(c => c.fitToView())
let reset = (cmd: refCommands) => cmd.current->Belt.Option.forEach(c => c.reset())

let useOrientation = init => {
  let (orientation, setOrientation) = React.useState(init)
  let flip = () =>
    setOrientation(prev =>
      switch prev {
      | #vertical => #horizontal
      | _ => #vertical
      }
    )
  (orientation, flip)
}

@react.component
let make = (
  ~width=?,
  ~height=?,
  ~className=?,
  ~minScale=0.1,
  ~maxScale=1.5,
  ~orientation: Diagram__Layout.orientation=#vertical,
  ~boundingBox=false,
  ~selectionZoom=false,
  ~nodeSep=50,
  ~edgeSep=10,
  ~rankSep=50,
  ~commands: option<React.ref<option<commands>>>=?,
  ~onLayoutUpdate=?,
  ~children,
) => {
  let zoomable = !(minScale == maxScale && width == None && height == None)

  let diagramNode = React.useRef(None)
  let canvasNode = React.useRef(None)
  let clickCoordinates = React.useRef((0., 0., 0., 0.))
  let rectangleZooming = React.useRef(false)
  let slidingEnabled = React.useRef(false)

  let (fitToViewFn, setFitToViewFn) = React.Uncurried.useState(() => None)
  let (resetFn, setResetFn) = React.Uncurried.useState(() => None)
  let (resizeFn, setResizeFn) = React.Uncurried.useState(() => None)

  React.useImperativeHandle2(
    Js.Nullable.fromOption(commands),
    () => {
      switch (resetFn, fitToViewFn) {
      | (Some(reset), Some(fitToView)) =>
        let _ = Js_global.setTimeout(() => fitToView(), 0)
        Some({
          reset,
          fitToView,
        })
      | _ => None
      }
    },
    (fitToViewFn, resetFn),
  )

  React.useEffect1(() => {
    switch diagramNode.current {
    | Some(container) =>
      container
      ->Diagram__Layout.get
      ->Diagram__Layout.registerListener(onLayoutUpdate->Belt.Option.getWithDefault(() => ()))
    | None => ()
    }
    None
  }, [onLayoutUpdate])

  switch diagramNode.current {
  | Some(container) => container->Diagram__Layout.get->Diagram__Layout.setOrientation(orientation)
  | None => ()
  }

  let initRender = domNode => {
    diagramNode.current = domNode->Js.toOption
    switch diagramNode.current {
    | Some(container) =>
      open Belt.Option
      canvasNode.current = container->Diagram__Dom.firstChild->Js.toOption
      Diagram__DOMRenderer.render(children, container, nodeSep, edgeSep, rankSep, (t, l) => {
        let update = (changeScale, center, resize, ()) => {
          if resize {
            let (canvasWidth, canvasHeight) = t->Diagram__Transform.getBBox
            container
            ->Diagram__Dom.style
            ->Js.Dict.set("width", Js.Float.toString(canvasWidth) ++ "px")
            container
            ->Diagram__Dom.style
            ->Js.Dict.set("height", Js.Float.toString(canvasHeight) ++ "px")
          } else {
            let (canvasWidth, canvasHeight) = t->Diagram__Transform.getBBox
            // compute center
            let (x, y, scale) = if center {
              if canvasWidth > 0. && canvasHeight > 0. {
                let {width: containerWidth, height: containerHeight} =
                  container->Diagram__Dom.getBoundingClientRect
                // change scale if wanted
                let scale = if changeScale {
                  let realScale =
                    0.98 /.
                    Js.Math.max_float(
                      canvasWidth /. containerWidth,
                      canvasHeight /. containerHeight,
                    )
                  Js.Math.min_float(1.0, Js.Math.max_float(minScale, realScale))
                } else {
                  t->Diagram__Transform.scale
                }

                let x = containerWidth /. 2. -. scale *. (canvasWidth /. 2.)
                let y = containerHeight /. 2. -. scale *. (canvasHeight /. 2.)
                (x, y, scale)
              } else {
                (0., 0., 1.)
              }
            } else {
              (0., 0., 1.)
            }

            t->Diagram__Transform.update((x, y), scale)
            canvasNode.current->forEach(canvas => canvas->Diagram__Dom.setTransform(x, y, scale))
          }
        }
        l->Diagram__Layout.setDisplayBBox(boundingBox)
        l->Diagram__Layout.setOrientation(orientation)
        setResetFn(_ => Some(update(true, false, false, ...)))
        setFitToViewFn(_ => Some(update(true, true, false, ...)))
        setResizeFn(_ => Some(update(false, false, true, ...)))
      })
    | None => ()
    }
  }

  let onPointerDown = e => {
    let capture = () =>
      e
      ->Diagram__Dom.mouseEventTarget
      ->Diagram__Dom.setPointerCapture(e->Diagram__Dom.mousePointerId)

    switch diagramNode.current {
    | Some(containerNode) if e->Diagram__Dom.mouseEventTarget == containerNode =>
      switch e->Diagram__Dom.mouseEventButton {
      | 0 /* left */ if selectionZoom =>
        capture()
        rectangleZooming.current = true

        let {left: containerLeft, top: containerTop, _} =
          containerNode->Diagram__Dom.getBoundingClientRect
        let px = e->Diagram__Dom.clientX -. containerLeft
        let py = e->Diagram__Dom.clientY -. containerTop
        clickCoordinates.current = (px, py, 0., 0.)

        let element = Diagram__Dom.Document.createElement("div")
        element->Diagram__DOMReconciler.setStyles(
          Js.Dict.fromArray([
            ("position", Js.Nullable.return("absolute")),
            ("transformOrigin", Js.Nullable.return("0 0")),
            ("pointerEvents", Js.Nullable.return("none")),
            ("outline", Js.Nullable.return("1px dashed yellowgreen")),
            ("width", Js.Nullable.return("1px")),
            ("height", Js.Nullable.return("1px")),
            (
              "transform",
              Js.Nullable.return(
                "translate3d(" ++
                Js.Float.toString(px) ++
                "px, " ++
                Js.Float.toString(py) ++ "px, 0px)",
              ),
            ),
          ]),
        )
        containerNode->Diagram__Dom.appendChild(element)
      | 1 /* middle/wheel */ if zoomable =>
        capture()
        containerNode->Diagram__Dom.style->Js.Dict.set("cursor", "move")
        slidingEnabled.current = true
      | _ => ()
      }
    | _ => ()
    }
  }

  let slide = e =>
    if rectangleZooming.current {
      let (px, py, w, h) = clickCoordinates.current

      diagramNode.current->Belt.Option.forEach(n =>
        n
        ->Diagram__Dom.lastChild
        ->Js.toOption
        ->Belt.Option.forEach(l => {
          let mx = e->Diagram__Dom.movementX
          let my = e->Diagram__Dom.movementY
          let w' = w +. mx
          let h' = h +. my
          clickCoordinates.current = (px, py, w', h')
          l->Diagram__Dom.setStyleTransform(
            "translate3d(" ++
            Js.Float.toString(Js.Math.min_float(px, px +. w')) ++
            "px, " ++
            Js.Float.toString(py) ++ "px, 0px)",
          )
          l->Diagram__Dom.setStyleWidth(Js.Float.toString(Js.Math.abs_float(w')) ++ "px")
          l->Diagram__Dom.setStyleHeight(Js.Float.toString(Js.Math.abs_float(h')) ++ "px")
        })
      )
      e->Diagram__Dom.stopPropagation()
    } else if slidingEnabled.current {
      switch (diagramNode.current, canvasNode.current) {
      | (Some(container), Some(canvas)) =>
        let transform = container->Diagram__Transform.get

        let (x, y) = transform->Diagram__Transform.origin
        let scale = transform->Diagram__Transform.scale

        let x' = x +. Js.Int.toFloat(e->ReactEvent.Mouse.movementX)
        let y' = y +. Js.Int.toFloat(e->ReactEvent.Mouse.movementY)

        transform->Diagram__Transform.update((x', y'), scale)
        canvas->Diagram__Dom.setTransform(x', y', scale)

        let {width, height} = container->Diagram__Dom.getBoundingClientRect
        let ccx = width /. 2.
        let ccy = height /. 2.

        let (bboxWidth, bboxHeight) = transform->Diagram__Transform.getBBox

        let bbwh = bboxWidth *. scale /. 2.
        let bbhh = bboxHeight *. scale /. 2.
        let bbcx = x' +. bbwh // bbox center x
        let bbcy = y' +. bbhh // bbox center y

        let displayGps =
          bbcy +. bbhh < 0. || bbcx +. bbwh < 0. || bbcx -. bbwh > width || bbcy -. bbhh > height

        container
        ->Diagram__Dom.lastChild
        ->Js.toOption
        ->Belt.Option.forEach(gps => {
          gps->Diagram__Dom.style->Js.Dict.set("display", displayGps ? "block" : "none")
          gps->Diagram__Dom.setTranslate3d(ccx -. 25., ccy -. 25.)
          // arrow
          switch gps->Diagram__Dom.lastChild->Js.toOption {
          | Some(arrow) if displayGps =>
            let (vnx, vny) = Diagram__Graphics.normalizeVector(bbcx -. ccx, bbcy -. ccy)
            let vx = 25. *. vnx
            let vy = 25. *. vny

            let arrowPoints = Diagram__Graphics.createArrowPoints(
              25. +. vx,
              25. +. vy,
              25. +. bbcx -. ccx,
              25. +. bbcy -. ccy,
              false,
            )
            arrow->Diagram__Dom.setAttribute("points", arrowPoints)
          | _ => ()
          }
        })

      | _ => ()
      }
    }

  let onPointerUp = e => {
    let release = () =>
      e
      ->Diagram__Dom.mouseEventTarget
      ->Diagram__Dom.releasePointerCapture(e->Diagram__Dom.mousePointerId)

    switch (diagramNode.current, canvasNode.current) {
    | (Some(node), _) if slidingEnabled.current =>
      slidingEnabled.current = false
      node->Diagram__Dom.style->Js.Dict.set("cursor", "initial")
      node
      ->Diagram__Dom.lastChild
      ->Js.toOption
      ->Belt.Option.forEach(n => n->Diagram__Dom.style->Js.Dict.set("display", "none"))
      release()
    | (Some(container), Some(canvas)) if rectangleZooming.current =>
      let {left: containerLeft, top: containerTop, width: containerWidth, _} =
        container->Diagram__Dom.getBoundingClientRect
      let pointerX = e->Diagram__Dom.clientX -. containerLeft
      let pointerY = e->Diagram__Dom.clientY -. containerTop
      let (startPointerX, startPointerY, _, _) = clickCoordinates.current
      let (px, px') =
        pointerX < startPointerX ? (pointerX, startPointerX) : (startPointerX, pointerX)
      let (py, py') =
        pointerY < startPointerY ? (pointerY, startPointerY) : (startPointerY, pointerY)
      let selectionWidth = px' -. px
      let _selectionHeight = py' -. py
      rectangleZooming.current = false
      release()
      diagramNode.current->Belt.Option.forEach(n =>
        n
        ->Diagram__Dom.lastChild
        ->Js.toOption
        ->Belt.Option.forEach(l => n->Diagram__Dom.removeChild(l))
      )

      let transform = container->Diagram__Transform.get
      //let (x, y) = transform->Diagram__Transform.origin
      let scale = transform->Diagram__Transform.scale

      let x' = /* x -. */ px -. startPointerX *. scale
      let y' = /* y -. */ py -. startPointerY *. scale
      let scale' = Js.Math.min_float(
        maxScale,
        Js.Math.max_float(minScale, scale *. containerWidth /. selectionWidth),
      )

      transform->Diagram__Transform.update((x', y'), scale')
      canvas->Diagram__Dom.setTransform(x', y', scale')
    | _ => ()
    }
  }

  let zoom = e =>
    switch (diagramNode.current, canvasNode.current) {
    | (Some(container), Some(canvas)) =>
      let eMouse = e->Diagram__Dom.asMouseEvent
      if eMouse->ReactEvent.Mouse.ctrlKey {
        eMouse->Diagram__Dom.stopPropagation()
        eMouse->Diagram__Dom.preventDefault()

        let transform = container->Diagram__Transform.get
        let (x, y) = transform->Diagram__Transform.origin
        let scale = transform->Diagram__Transform.scale

        let targetBBox = container->Diagram__Dom.getBoundingClientRect
        let pointerX = eMouse->Diagram__Dom.clientX -. targetBBox.left
        let pointerY = eMouse->Diagram__Dom.clientY -. targetBBox.top

        let x' = (pointerX -. x) /. scale
        let y' = (pointerY -. y) /. scale

        let scale' = scale +. e->ReactEvent.Wheel.deltaY *. -0.0005 *. scale
        let scale'' = Js.Math.min_float(maxScale, Js.Math.max_float(minScale, scale'))

        let x'' = pointerX -. x' *. scale''
        let y'' = pointerY -. y' *. scale''

        transform->Diagram__Transform.update((x'', y''), scale'')
        canvas->Diagram__Dom.setTransform(x'', y'', scale'')
      }
    | _ => ()
    }

  React.useEffect2(() => {
    switch diagramNode.current {
    | Some(container) if zoomable =>
      container->Diagram__Dom.addEventListenerWithOptions(
        "wheel",
        zoom,
        {"capture": false, "once": false, "passive": false},
      )
      Some(() => container->Diagram__Dom.removeEventListener("wheel", zoom))
    | _ => None
    }
  }, (zoom, zoomable))

  switch resizeFn {
  | Some(resize) if !zoomable => Js_global.setTimeout(resize, 0)->ignore
  | _ => ()
  }

  <WithPointerEvents onPointerDown onPointerUp onPointerMove=slide>
    <div
      ref={ReactDOM.Ref.callbackDomRef(initRender)}
      ?className
      style={{?JsxDOMStyle.width, ?height, position: "relative", overflow: "hidden"}}>
      <div style={{JsxDOMStyle.position: "relative", transformOrigin: "0 0"}} />
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 50 50"
        width="50px"
        height="50px"
        style={{JsxDOMStyle.pointerEvents: "none", display: "none"}}>
        <circle cx="25" cy="25" r="12" fill="none" />
        <polygon />
      </svg>
    </div>
  </WithPointerEvents>
}
