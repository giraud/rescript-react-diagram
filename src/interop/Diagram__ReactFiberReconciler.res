type rootContainer = Dom.element
type instance = Dom.element
type internalHandle
type timestamp
type elementType = string
type context<'a> = Js.t<'a>

type jsProp // Opaque prop from js
type props = Js.Dict.t<jsProp>

/**
 See https://github.com/facebook/react/tree/main/packages/react-reconciler
 Comments are copied from this page
 */
type hostConfig<'c, 'commit> = {
  isPrimaryRenderer: bool,
  supportsMutation: bool,
  useSyncScheduling: bool,
  //
  getRootHostContext: rootContainer => context<'c>,
  getChildHostContext: (context<'c>, elementType, rootContainer) => context<'c>,
  getPublicInstance: instance => instance,
  /**
   This method is called for a container that's used as a portal target. Usually you can leave it empty.
 */
  preparePortalMount: rootContainer => unit /* ? */,
  /**
   This method should return a newly created node.
   For example, the DOM renderer would call document.createElement(type) here and then set the properties from props.

   You can use rootContainer to access the root container associated with that tree.
   For example, in the DOM renderer, this is useful to get the correct document reference that the root belongs to.

   The hostContext parameter lets you keep track of some information about your current place in the tree.

   This method happens in the render phase.
   It can (and usually should) mutate the node it has just created before returning it, but it must not modify any other nodes.
 */
  createInstance: (elementType, props, rootContainer, context<'c>, internalHandle) => Dom.element,
  /**
   Same as createInstance, but for text nodes.
 */
  createTextInstance: (string, props, internalHandle) => Dom.element,
  /**
   This method should mutate the parentInstance and add the child to its list of children.
   For example, in the DOM this would translate to a parentInstance.appendChild(child) call.

   This method happens in the render phase.
   It can mutate parentInstance and child, but it must not modify any other nodes.
   It's called while the tree is still being built up and not connected to the actual tree on the screen.
 */
  appendInitialChild: (Dom.element, Dom.element) => unit,
  /**
   In this method, you can perform some final mutations on the instance.
   Unlike with createInstance, by the time finalizeInitialChildren is called, all the initial children have already been added to the instance,
   but the instance itself has not yet been connected to the tree on the screen.

   This method happens in the render phase.
   It can mutate instance, but it must not modify any other nodes.
   It's called while the tree is still being built up and not connected to the actual tree on the screen.

   There is a second purpose to this method.
   It lets you specify whether there is some work that needs to happen when the node is connected to the tree on the screen.
   If you return true, the instance will receive a commitMount call later. See its documentation below.

   If you don't want to do anything here, you should return false.
 */
  finalizeInitialChildren: (instance, elementType, props, rootContainer, context<'c>) => bool,
  /**
   Some target platforms support setting an instance's text content without manually creating a text node.
   For example, in the DOM, you can set node.textContent instead of creating a text node and appending it.
 */
  shouldSetTextContent: (elementType, props) => bool,
  /**
   React calls this method so that you can compare the previous and the next props,
   and decide whether you need to update the underlying instance or not.

   If you don't need to update it, return null.
   If you need to update it, you can return an arbitrary object representing the changes that need to happen.
   Then in commitUpdate you would need to apply those changes to the instance.

   This method happens in the render phase. It should only calculate the update ? but not apply it!
 */
  prepareUpdate: (Dom.element, elementType, props, props) => array<string>,
  /**
   This method should mutate the instance according to the set of changes in updatePayload.

   Here, updatePayload is the object that you've returned from prepareUpdate and has an arbitrary structure that makes sense for your renderer.
   For example, the DOM renderer returns an update payload like [prop1, value1, prop2, value2, ...] from prepareUpdate,
   and that structure gets passed into commitUpdate.

   Ideally, all the diffing and calculation should happen inside prepareUpdate so that commitUpdate can be fast and straightforward.
 */
  commitUpdate: (Dom.element, array<string>, elementType, props, props, internalHandle) => unit,
  /**
   This method lets you store some information before React starts making changes to the tree on the screen.
   For example, the DOM renderer stores the current text selection so that it can later restore it.
   This method is mirrored by resetAfterCommit.
 */
  prepareForCommit: Dom.element => Js.nullable<'commit>,
  /**
  This method is called right after React has performed the tree mutations.
  You can use it to restore something you've stored in prepareForCommit ? for example, text selection.
 */
  resetAfterCommit: Dom.element => unit,
  /**
   This method should mutate the textInstance and update its text content to nextText.
 */
  commitTextUpdate: (Dom.element, string, string) => unit,
  /**
   If you returned true from shouldSetTextContent for the previous props, but returned false from shouldSetTextContent for the next props,
   React will call this method so that you can clear the text content you were managing manually.
   For example, in the DOM you could set node.textContent = ''.
 */
  resetTextContent: Dom.element => unit,
  //
  insertBefore: (Dom.element, Dom.element, Dom.element) => unit,
  insertInContainerBefore: (Dom.element, Dom.element, Dom.element) => unit,
  /**
   This method should mutate the parentInstance and add the child to its list of children.
   For example, in the DOM this would translate to a parentInstance.appendChild(child) call.

   Although this method currently runs in the commit phase, you still should not mutate any other nodes in it.
   If you need to do some additional work when a node is definitely connected to the visible tree, look at commitMount.
 */
  appendChild: (Dom.element, Dom.element) => unit,
  /**
   Same as appendChild, but for when a node is attached to the root container.
   This is useful if attaching to the root has a slightly different implementation,
   or if the root container nodes are of a different type than the rest of the tree.
 */
  appendChildToContainer: (Dom.element, Dom.element) => unit,
  /**
   This method should mutate the parentInstance to remove the child from the list of its children.

   React will only call it for the top-level node that is being removed.
   It is expected that garbage collection would take care of the whole subtree.
   You are not expected to traverse the child tree in it.
 */
  removeChild: (Dom.element, Dom.element) => unit,
  /**
   Same as removeChild, but for when a node is detached from the root container.
   This is useful if attaching to the root has a slightly different implementation, or if the root container nodes are of a different type
   than the rest of the tree.
 */
  removeChildFromContainer: (Dom.element, Dom.element) => unit,
  /*
  no info
 */
  detachDeletedInstance: Dom.element => unit,
  /**
   This method is only called if you returned true from finalizeInitialChildren for this instance.

   It lets you do some additional work after the node is actually attached to the tree on the screen for the first time.
   For example, the DOM renderer uses it to trigger focus on nodes with the autoFocus attribute.

   Note that commitMount does not mirror removeChild one to one because removeChild is only called for the top-level removed node.
   This is why ideally commitMount should not mutate any nodes other than the instance itself.
   For example, if it registers some events on some node above, it will be your responsibility to traverse the tree in removeChild and clean them up,
   which is not ideal.

   The internalHandle data structure is meant to be opaque.
   If you bend the rules and rely on its internal fields, be aware that it may change significantly between versions.
   You're taking on additional maintenance risk by reading from it, and giving up all guarantees if you write something to it.

   If you never return true from finalizeInitialChildren, you can leave it empty.
 */
  commitMount: (instance, elementType, props, internalHandle) => unit,
  /**
  This method should mutate the container root node and remove all children from it.
 */
  clearContainer: rootContainer => unit,
}

/**
 The reconciler once it has been created from the host config.
 */
type t = {
  createContainer: Dom.element => Dom.element,
  updateContainer: (
    React.element,
    Dom.element,
    Js.nullable<Dom.element>,
    option<unit => unit>,
  ) => unit,
}

@module("react-reconciler")
external make: hostConfig<'c, 'context> => t = "default"
