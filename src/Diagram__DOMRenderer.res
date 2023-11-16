module DataNodeReactRoot = {
  @set external attach: (Dom.element, 'a) => unit = "_reactRootContainer"
  @get external detach: Dom.element => Js.nullable<'a> = "_reactRootContainer"
}

let render = (element, container, nodeSep, edgeSep, rankSep, onCreation) => {
  let root = switch container->DataNodeReactRoot.detach->Js.toOption {
  | Some(node) => node
  | None =>
    // Clear canvas
    container->Diagram__Dom.forFirstChild(canvas =>
      canvas
      ->Diagram__Dom.children
      ->Belt.Array.forEach(node => container->Diagram__Dom.removeChild(node))
    )

    let newRoot = Diagram__DOMReconciler.reconciler.createContainer(container)
    let transform = Diagram__Transform.make()
    let layout = Diagram__Layout.make(~nodeSep, ~edgeSep, ~rankSep)

    container->DataNodeReactRoot.attach(newRoot)
    container->Diagram__Transform.attach(transform)
    container->Diagram__Layout.attach(layout)

    onCreation(transform, layout)

    newRoot
  }

  Diagram__DOMReconciler.reconciler.updateContainer(element, root, Js.Nullable.null, None)
}
