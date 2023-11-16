module Dom = Diagram__Dom

@module("../../../src/debug.js")
external debugMethods: (
  Diagram__ReactFiberReconciler.hostConfig<'b, 'c>,
  array<string>,
) => Diagram__ReactFiberReconciler.hostConfig<'b, 'c> = "debugMethods"
@module("../../../src/debug.js")
external noDebugMethods: (
  Diagram__ReactFiberReconciler.hostConfig<'b, 'c>,
  array<string>,
) => Diagram__ReactFiberReconciler.hostConfig<'b, 'c> = "noDebugMethods"

external jsPropToBool: Diagram__ReactFiberReconciler.jsProp => bool = "%identity"
external jsPropToString: Diagram__ReactFiberReconciler.jsProp => string = "%identity"
external jsPropToLabelPos: Diagram__ReactFiberReconciler.jsProp => Diagram__Layout.labelPos =
  "%identity"

let getRootContainer = instance => {
  let parentNode = instance->Dom.parentNode->Js.toOption
  parentNode->Belt.Option.flatMap(node => node->Dom.parentNode->Js.toOption)
}

let isEventName = name =>
  name->Js.String2.startsWith("on") && Dom.Window.hasOwnProperty(name->Js.String2.toLowerCase)

let createNode = id => {
  let element = Dom.Document.createElement("div")
  element->Dom.setAttribute("data-node", id)
  element->Dom.setAttribute("style", "position:absolute;")
  element
}

let createEdge = (id, label) => {
  let g = Dom.Document.createElement("div")
  g->Dom.setAttribute("style", "display:contents")

  let element = Dom.Document.createElementNS("http://www.w3.org/2000/svg", "svg")
  element->Dom.setAttribute("data-edge", id)
  element->Dom.setAttribute("style", "position:absolute;pointer-events:none;")

  let path = Dom.Document.createElementNS("http://www.w3.org/2000/svg", "path")
  path->Dom.setAttribute("fill", "none")

  let start = Dom.Document.createElementNS("http://www.w3.org/2000/svg", "circle")
  start->Dom.setAttribute("r", "4")

  //  let n = Dom.Document.createElementNS("http://www.w3.org/2000/svg", "path")
  //  n->Dom.setAttribute("fill", "none")

  let arrow = Dom.Document.createElementNS("http://www.w3.org/2000/svg", "polygon")

  let text = Dom.Document.createElement("div")
  text->Dom.setAttribute("data-edge-label", id)
  text->Dom.setAttribute("style", "position:absolute;display:inline-block")
  text->Dom.setTextContent(label)

  element->Dom.appendChild(path)
  element->Dom.appendChild(start)
  element->Dom.appendChild(arrow)
  //  element->Dom.appendChild(n)

  g->Dom.appendChild(element)
  g->Dom.appendChild(text)

  g
}

let createMap = () => {
  let element = Dom.Document.createElement("div")
  element->Dom.setAttribute("data-map", "")
  element->Dom.setAttribute("style", "position:absolute;")
  element
}

let setStyles = (domElement, styles) =>
  Js.Dict.keys(styles)->Belt.Array.forEach(name => {
    let style = domElement->Dom.style
    switch styles->Js.Dict.unsafeGet(name)->Js.toOption {
    | None => style->Js.Dict.set(name, "")
    | Some(value) if value == "" => style->Js.Dict.set(name, "")
    | Some(value) if Js.typeof(value) == "boolean" => style->Js.Dict.set(name, "")
    | Some(value) => style->Js.Dict.set(name, value)
    }
  })

let shallowDiff = (oldObj, newObj) => {
  let oldKeys = Js.Dict.keys(oldObj)
  let newKeys = Js.Dict.keys(newObj)
  let uniqueKeys = oldKeys->Belt.Set.String.fromArray->Belt.Set.String.mergeMany(newKeys)

  uniqueKeys
  ->Belt.Set.String.toArray
  ->Belt.Array.keep(name => oldObj->Js.Dict.unsafeGet(name) !== newObj->Js.Dict.unsafeGet(name))
}

let updateBBox = rootContainer =>
  rootContainer->Dom.forFirstChild(canvasNode =>
    canvasNode->Dom.forFirstChild(boxNode => {
      let (width, height) = rootContainer->Diagram__Transform.get->Diagram__Transform.toPixels
      boxNode->Dom.style->Js.Dict.set("width", width)
      boxNode->Dom.style->Js.Dict.set("height", height)
    })
  )

@val @scope("Number")
external maxSafeFloat: float = "MAX_SAFE_INTEGER"
@val @scope("Number")
external minSafeFloat: float = "MIN_SAFE_INTEGER"

let runLayout = rootContainer => {
  let layout = rootContainer->Diagram__Layout.get
  let transform = rootContainer->Diagram__Transform.get

  // compute a new layout
  layout->Diagram__Layout.run(rootContainer)

  // compute diagram boundingBox
  transform->Diagram__Transform.resetBBox
  layout->Diagram__Layout.processNodes((_, nodeInfo) =>
    transform->Diagram__Transform.computeBBox(
      nodeInfo.x,
      nodeInfo.y,
      nodeInfo.width,
      nodeInfo.height,
    )
  )
  layout->Diagram__Layout.processEdges((_, edgeInfo) =>
    // Use label bbox if it exist, use points bbox else
    switch (edgeInfo.x, edgeInfo.y) {
    | (Some(labelX), Some(labelY)) =>
      transform->Diagram__Transform.computeBBox(labelX, labelY, edgeInfo.width, edgeInfo.height)
    | _ =>
      let (pMinX, pMinY, pMaxX, pMaxY) =
        edgeInfo.points->Belt.Array.reduce(
          (maxSafeFloat, maxSafeFloat, minSafeFloat, minSafeFloat),
          ((minX, minY, maxX, maxY), {x, y}) => (
            x < minX ? x : minX,
            y < minY ? y : minY,
            maxX < x ? x : maxX,
            maxY < y ? y : maxY,
          ),
        )
      transform->Diagram__Transform.updateBBox(pMinX, pMinY, pMaxX, pMaxY)
    }
  )
  // update DOM
  rootContainer->updateBBox
}

@set @scope("dataset")
external setDataSetLayoutUpdated: (Dom.element, string) => unit = "layoutUpdated"
@get @scope("dataset") external getDataSetLayoutUpdated: Dom.element => string = "layoutUpdated"

let reconciler = Diagram__ReactFiberReconciler.make(
  noDebugMethods(
    {
      isPrimaryRenderer: false,
      supportsMutation: true,
      useSyncScheduling: true,
      getPublicInstance: instance => instance,
      preparePortalMount: _container => (),
      prepareForCommit: container => {
        container->Diagram__Layout.get->Diagram__Layout.reset
        container->Diagram__Transform.get->Diagram__Transform.resetBBox
        container->updateBBox
        Js.Nullable.null
      },
      resetAfterCommit: container => {
        let layoutUpdated = container->getDataSetLayoutUpdated

        // Callback onLayoutUpdate
        if layoutUpdated == "true" {
          container->Diagram__Layout.get->Diagram__Layout.onUpdate
          container->setDataSetLayoutUpdated("false")
        }
      },
      //
      createInstance: (elementType, props, rootContainer, _context, _internalHandle) => {
        let element = switch elementType {
        | "Node" =>
          rootContainer->setDataSetLayoutUpdated("true")
          createNode(
            props->Js.Dict.get("nodeId")->Belt.Option.mapWithDefault("nodeId", jsPropToString),
          )
        | "Edge" =>
          rootContainer->setDataSetLayoutUpdated("true")
          let source =
            props->Js.Dict.get("source")->Belt.Option.mapWithDefault("source", jsPropToString)
          let target =
            props->Js.Dict.get("target")->Belt.Option.mapWithDefault("target", jsPropToString)
          let label =
            props
            ->Js.Dict.get("label")
            ->Belt.Option.mapWithDefault("name-" ++ source ++ "-" ++ target, jsPropToString)
          let id = source ++ "-" ++ target ++ "-" ++ label
          createEdge(
            id,
            props->Js.Dict.get("label")->Belt.Option.mapWithDefault("", jsPropToString),
          )
        | "Map" => createMap()
        | "svg"
        | "circle"
        | "path"
        | "rect"
        | "g" =>
          Dom.Document.createElementNS("http://www.w3.org/2000/svg", elementType)
        | _ => Dom.Document.createElement(elementType)
        }

        element
      },
      //
      createTextInstance: (text, _, _) => Dom.Document.createTextNode(text),
      shouldSetTextContent: (_elementType, props) => {
        let children = props->Js.Dict.unsafeGet("children")
        Js.typeof(children) == "string" || Js.typeof(children) == "number"
      },
      //
      getRootHostContext: _rootContainer => {
        Js.Obj.empty()
      },
      getChildHostContext: (parentHostContext, _elementType, _rootContainer) => parentHostContext,
      //
      appendInitialChild: (parentInstance, child) => parentInstance->Dom.appendChild(child),
      appendChild: (parentInstance, child) => parentInstance->Dom.appendChild(child),
      appendChildToContainer: (rootContainer, child) =>
        switch child->Dom.dataset->Js.Dict.get("map") {
        | None => rootContainer->Dom.forFirstChild(canvas => canvas->Dom.appendChild(child))
        | Some(_) => rootContainer->Dom.appendChild(child)
        },
      //
      removeChild: (parentInstance, child) => parentInstance->Dom.removeChild(child),
      removeChildFromContainer: (rootContainer, child) =>
        switch child->Dom.dataset->Js.Dict.get("map") {
        | None =>
          rootContainer->setDataSetLayoutUpdated("true")
          rootContainer->Dom.forFirstChild(canvas => canvas->Dom.removeChild(child))
        | Some(_) => rootContainer->Dom.removeChild(child)
        },
      //
      detachDeletedInstance: _node => (),
      //
      insertBefore: (parentInstance, child, beforeChild) =>
        parentInstance->Dom.insertBefore(child, beforeChild),
      insertInContainerBefore: (rootContainer, child, beforeChild) =>
        switch beforeChild->Dom.dataset->Js.Dict.get("map") {
        | Some(_) => rootContainer->Dom.forFirstChild(canvas => canvas->Dom.appendChild(child))
        | None =>
          switch child->Dom.dataset->Js.Dict.get("map") {
          | None =>
            rootContainer->Dom.forFirstChild(canvas => canvas->Dom.insertBefore(child, beforeChild))
          | Some(_) => rootContainer->Dom.insertBefore(child, beforeChild)
          }
        },
      //
      finalizeInitialChildren: (domElement, elementType, props, _rootContainer, _hostContext) => {
        props
        ->Js.Dict.keys
        ->Belt.Array.forEach(key => {
          switch (elementType, key) {
          | ("Node", "nodeId") => ()
          | ("Node", "style") => ()
          | ("Edge", "from") => ()
          | ("Edge", "to") => ()
          | ("Edge", "label") => ()
          | ("Edge", "style") => ()
          | (_, "children") =>
            // Set the textContent only for literal string or number children, whereas
            // nodes will be appended in `appendChild`
            let children = props->Js.Dict.unsafeGet("children")
            if Js.typeof(children) == "string" || Js.typeof(children) == "number" {
              domElement->Dom.setTextContent(children->jsPropToString)
            }
          | (_, "className") =>
            domElement->Dom.setAttribute(
              "class",
              props->Js.Dict.unsafeGet("className")->jsPropToString,
            )
          | (_, "style") => domElement->setStyles(Obj.magic(props->Js.Dict.unsafeGet("style")))
          | (_, name /* , value */) if isEventName(name) =>
            let eventName = name->Js.String2.toLowerCase->Js.String2.replace("on", "")
            domElement->Dom.addEventListener(eventName, props->Js.Dict.unsafeGet(name))
          | (_, name) if name == "disabled" =>
            let value = props->Js.Dict.get(name)->Belt.Option.mapWithDefault(false, jsPropToBool)
            if value == true {
              domElement->Dom.setAttribute(name, "")
            } else {
              domElement->Dom.removeAttribute(name)
            }
          | (_, name) =>
            domElement->Dom.setAttribute(name, props->Js.Dict.unsafeGet(name)->jsPropToString)
          }
        })

        elementType == "Node" || elementType == "Edge"
      },
      //
      prepareUpdate: (_domElement, _elementType, oldProps, newProps) =>
        shallowDiff(oldProps, newProps),
      //
      commitUpdate: (
        domElement,
        updatePayload,
        elementType,
        oldProps,
        newProps,
        _internalHandle,
      ) => {
        updatePayload->Belt.Array.forEach(propName => {
          let newValue = newProps->Js.Dict.get(propName)

          if propName === "children" {
            // children changes is done by the other methods like `commitTextUpdate`
            if Js.typeof(newValue) == "string" || Js.typeof(newValue) == "number" {
              domElement->Dom.setTextContent(Obj.magic(newValue))
            }
          } else if propName === "style" {
            // Return a diff between the new and the old styles
            let oldStyle: Js.Dict.t<'a> = Obj.magic(oldProps->Js.Dict.unsafeGet("style"))
            let newStyle: Js.Dict.t<'a> = Obj.magic(newProps->Js.Dict.unsafeGet("style"))
            let styleDiffs = shallowDiff(oldStyle, newStyle)

            let finalStyles = styleDiffs->Belt.Array.reduce(Js.Dict.empty(), (acc, styleName) => {
              let newStyleValue = newStyle->Js.Dict.get(styleName)
              switch newStyleValue {
              | None => acc->Js.Dict.set(styleName, Js.Nullable.return(""))
              | Some(value) => acc->Js.Dict.set(styleName, Js.Nullable.return(value))
              }
              acc
            })

            domElement->setStyles(finalStyles)
          } else {
            switch newValue {
            | None if isEventName(propName) =>
              // event is not here anymore
              let eventName = propName->Js.String2.toLowerCase->Js.String2.replace("on", "")
              domElement->Dom.removeEventListener(eventName, oldProps->Js.Dict.unsafeGet(propName))
            | None =>
              // attribute is not here anymore
              domElement->Dom.removeAttribute(propName)
            | Some(event) if isEventName(propName) =>
              let eventName = propName->Js.String2.toLowerCase->Js.String2.replace("on", "")
              domElement->Dom.removeEventListener(eventName, oldProps->Js.Dict.unsafeGet(propName))
              domElement->Dom.addEventListener(eventName, event)
            | Some(attribute) if propName == "className" =>
              domElement->Dom.setAttribute("class", attribute->jsPropToString)
            | Some(attribute) => domElement->Dom.setAttribute(propName, attribute->jsPropToString)
            }
          }
        })

        switch getRootContainer(domElement) {
        | None => ()
        | Some(container) =>
          switch elementType {
          | "Node" =>
            switch newProps->Js.Dict.get("nodeId")->Belt.Option.map(jsPropToString) {
            | None => ()
            | Some(id) =>
              let rect = Dom.getBoundingClientRect(domElement)
              let scale = container->Diagram__Transform.get->Diagram__Transform.scale
              container
              ->Diagram__Layout.get
              ->Diagram__Layout.setNode(id, rect.width /. scale, rect.height /. scale)
            }
          | "Edge" =>
            switch (
              newProps->Js.Dict.get("source")->Belt.Option.map(jsPropToString),
              newProps->Js.Dict.get("target")->Belt.Option.map(jsPropToString),
              newProps
              ->Js.Dict.get("labelPos")
              ->Belt.Option.mapWithDefault(#center, jsPropToLabelPos),
              domElement->Dom.lastChild->Js.toOption,
            ) {
            | (Some(source), Some(target), labelPos, Some(domEdgeLabel)) =>
              let rect = Dom.getBoundingClientRect(domEdgeLabel)
              let scale = container->Diagram__Transform.get->Diagram__Transform.scale
              container
              ->Diagram__Layout.get
              ->Diagram__Layout.setEdge(
                source,
                target,
                newProps->Js.Dict.get("label")->Belt.Option.map(jsPropToString),
                rect.width /. scale,
                rect.height /. scale,
                labelPos,
              )
            | _ => ()
            }
          | _ => ()
          }

          switch elementType {
          | "Node"
          | "Edge" =>
            runLayout(container)
          | _ => ()
          }
        }
      },
      //
      commitTextUpdate: (domElement, _oldText, newText) => {
        domElement->Dom.setNodeValue(newText)
      },
      //
      resetTextContent: domElement => {
        domElement->Dom.setTextContent("")
      },
      //
      commitMount: (domElement, elementType, props, _internalHandle) =>
        switch getRootContainer(domElement) {
        | None => ()
        | Some(container) =>
          open Diagram__Layout
          let layout = container->get

          switch elementType {
          | "Node" =>
            switch props->Js.Dict.get("nodeId")->Belt.Option.map(jsPropToString) {
            | None => ()
            | Some(id) =>
              let rect = Dom.getBoundingClientRect(domElement)
              let scale = container->Diagram__Transform.get->Diagram__Transform.scale
              layout->setNode(id, rect.width /. scale, rect.height /. scale)
            }
          | "Edge" =>
            switch (
              props->Js.Dict.get("source")->Belt.Option.map(jsPropToString),
              props->Js.Dict.get("target")->Belt.Option.map(jsPropToString),
              props->Js.Dict.get("labelPos")->Belt.Option.mapWithDefault(#center, jsPropToLabelPos),
              domElement->Dom.lastChild->Js.toOption,
            ) {
            | (Some(source), Some(target), labelPos, Some(domEdgeLabel)) =>
              let rect = Dom.getBoundingClientRect(domEdgeLabel)
              let scale = container->Diagram__Transform.get->Diagram__Transform.scale
              layout->setEdge(
                source,
                target,
                props->Js.Dict.get("label")->Belt.Option.map(jsPropToString),
                rect.width /. scale,
                rect.height /. scale,
                labelPos,
              )
            | _ => ()
            }
          | _ => ()
          }

          switch elementType {
          | "Node"
          | "Edge" =>
            runLayout(container)
          | _ => ()
          }
        },
      //
      clearContainer: rootContainer => {
        rootContainer
        ->Dom.firstChild
        ->Js.toOption
        ->Belt.Option.forEach(canvas => {
          canvas->Dom.setTextContent("")
          let element = Diagram__Dom.Document.createElement("div")
          element->setStyles(
            Js.Dict.fromArray([
              ("position", Js.Nullable.return("absolute")),
              ("transformOrigin", Js.Nullable.return("0 0")),
              ("pointerEvents", Js.Nullable.return("none")),
              ("outline", Js.Nullable.return("1px dashed yellowgreen")),
              ("width", Js.Nullable.return("0px")),
              ("height", Js.Nullable.return("0px")),
              (
                "display",
                Js.Nullable.return(
                  rootContainer->Diagram__Layout.get->Diagram__Layout.displayBBox
                    ? "block"
                    : "none",
                ),
              ),
            ]),
          )
          canvas->Diagram__Dom.appendChild(element)
        })
      },
    },
    [
      /* methods to exclude from debug */
      "shouldSetTextContent",
      //      "getRootHostContext",
      "getChildHostContext",
    ],
  ),
)
