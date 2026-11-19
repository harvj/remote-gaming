lock "~> 3.20"
# The reviewed Git archive is uploaded from the operator's checkout.
set :scm, nil
set :application, "remote-gaming"
set :ssh_options, { forward_agent: false, verify_host_key: :always, auth_methods: %w[publickey], non_interactive: true }
