%%raw(`import '../../../example/App.css'`)

@val @scope("document")
external getElementById: string => Js.nullable<Dom.element> = "getElementById"

let layout1 = "A|B|C|A - B|A - C"

let parseDot = instructions => {
  instructions
  ->Js.String2.split("|")
  ->Belt.Array.keep(line => line->Js.String2.length > 0)
  ->Belt.Array.reduce(([], []), ((nodes, edges) as acc, line) => {
    switch line->Js.String2.split(" - ") {
    | [node] => (nodes->Belt.Array.concat([node]), edges)
    | [source, target] => (nodes, edges->Belt.Array.concat([(source, target)]))
    | _ => acc
    }
  })
}

let renderArray = (a, fn) => a->Belt.Array.map(fn)->React.array

module App = {
  @react.component
  let make = () => {
    let (initialNodes, initialEdges) = parseDot(layout1)

    let (id, setId) = React.useState(() => initialNodes->Belt.Array.length)
    let (start, setStart) = React.useState(() => "")
    let (end, setEnd) = React.useState(() => "")
    let (nodes, setNodes) = React.useState(() => initialNodes)
    let (edges, setEdges) = React.useState(() => initialEdges)

    let clear = _ => {
      setId(_ => 0)
      setStart(_ => "")
      setEnd(_ => "")
      setNodes(_ => [])
      setEdges(_ => [])
    }

    let addNode = _ => {
      setNodes(prev => prev->Belt.Array.concat([Js.Int.toString(id + 1)]))
      setId(id => id + 1)
    }

    let addEdge = _ => {
      setEdges(prev => prev->Belt.Array.concat([(start, end)]))
      setStart(_ => "")
      setEnd(_ => "")
    }

    let selectNode = id => {
      if id == start {
        setStart(_ => "")
      } else if id == end {
        setEnd(_ => "")
      } else if start == "" {
        setStart(_ => id)
      } else if end == "" {
        setEnd(_ => id)
      }
    }

    let selectNodes = (v, w) => {
      if start == v && end == w {
        setStart(_ => "")
        setEnd(_ => "")
      } else {
        setStart(_ => v)
        setEnd(_ => w)
      }
    }

    <main>
      <div className="toolbar">
        <button onClick={addNode}> {"Add node"->React.string} </button>
        <button onClick={addEdge} disabled={start == "" || end == ""}>
          {"Add edge"->React.string}
        </button>
        <button onClick={clear}> {"Clear"->React.string} </button>
      </div>
      <Diagram className="diagram" width="100%" height="100%">
        {nodes->renderArray(nodeId =>
          <Diagram.Node
            key={nodeId}
            nodeId={nodeId}
            className={start == nodeId ? "start" : end == nodeId ? "end" : ""}
            onClick={_ => selectNode(nodeId)}>
            {("Node " ++ nodeId)->React.string}
          </Diagram.Node>
        )}
        {edges->renderArray(((source, target)) =>
          <Diagram.Edge
            key={source ++ "-" ++ target}
            source
            target
            label="edge"
            onClick={_ => selectNodes(source, target)}
          />
        )}
      </Diagram>
    </main>
  }
}

switch getElementById("root")->Js.toOption {
| Some(root) => ReactDOM.render(<React.StrictMode> <App /> </React.StrictMode>, root)
| None => ()
}
