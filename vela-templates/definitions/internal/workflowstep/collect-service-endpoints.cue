import (
	"vela/op"
	"vela/ql"
	"strconv"
)

"collect-service-endpoints": {
	type: "workflow-step"
	annotations: {}
	labels: {}
	annotations: {
		"category": "Application Delivery"
	}
	description: "Collect service endpoints for the application."
}
template: {
	collect: ql.#CollectServiceEndpoints & {
		app: {
			name:      *context.name | string
			namespace: *context.namespace | string
			if parameter.name != _|_ {
				name: parameter.name
			}
			if parameter.namespace != _|_ {
				namespace: parameter.namespace
			}
			filter: {
				if parameter.components != _|_ {
					components: parameter.components
				}
			}
		}
	} @step(1)

	outputs: {
		eps_port_name_filtered: *[] | [...]
		if parameter.portName == _|_ {
			eps_port_name_filtered: collect.list
		}
		if parameter.portName != _|_ {
			eps_port_name_filtered: [ for ep in collect.list if parameter.portName == ep.endpoint.portName {ep}]
		}

		eps_port_filtered: *[] | [...]
		if parameter.port == _|_ {
			eps_port_filtered: eps_port_name_filtered
		}
		if parameter.port != _|_ {
			eps_port_filtered: [ for ep in eps_port_name_filtered if parameter.port == ep.endpoint.port {ep}]
		}
		eps:       eps_port_filtered
		endpoints: *[] | [...]
		if parameter.outer != _|_ {
			tmps: [ for ep in eps {
				ep
				if ep.endpoint.inner == _|_ {
					outer: true
				}
				if ep.endpoint.inner != _|_ {
					outer: !ep.endpoint.inner
				}
			}]
			endpoints: [ for ep in tmps if (!parameter.outer || ep.outer) {ep}]
		}
		if parameter.outer == _|_ {
			endpoints: eps_port_filtered
		}
	}

	wait: op.#ConditionalWait & {
		continue: len(outputs.endpoints) > 0
	} @step(2)

	value: {
		if len(outputs.endpoints) > 0 {
			endpoint: outputs.endpoints[0].endpoint
			_portStr: strconv.FormatInt(endpoint.port, 10)
			url:      "\(parameter.protocal)://\(endpoint.host):\(_portStr)"
		}
	}

	parameter: {
		// +usage=Specify the name of the application
		name?: string
		// +usage=Specify the namespace of the application
		namespace?: string
		// +usage=Filter the component of the endpoints
		components?: [...string]
		// +usage=Filter the port of the endpoints
		port?: int
		// +usage=Filter the port name of the endpoints
		portName?: string
		// +usage=Filter the endpoint that are only outer
		outer?: bool
		// +usage=The protocal of endpoint url
		protocal: *"http" | "https"
	}
}
