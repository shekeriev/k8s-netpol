#
# Demo 3
# 
# Inspired by:
# - MesosCon 2015 demo: https://github.com/mesosphere/star
# - Calico demo (based on the above): https://docs.projectcalico.org/security/tutorials/kubernetes-policy-demo/kubernetes-demo 
# 
# Modified / partially rewritten.
# The resulting code and all supporting files will be published here: https://github.com/shekeriev
#
# Main differences with Demo #2 are
# 1) this a working multi-container application (not a mockup); 
# 2) there is a sidecar container "attached" to the main container for each application component that acts as a visualization agent
# 

# Explore the *app.yaml manifests
cat 11-producer-app.yaml
cat 21-consumer-app.yaml
cat 31-observer-app.yaml

# As we can see, there is a sidecar container that act as a visualization agent

# Let's create the plot from a set of manifest files
kubectl apply -f 10-producer-ns.yaml
kubectl apply -f 11-producer-app.yaml
kubectl apply -f 20-consumer-ns.yaml
kubectl apply -f 21-consumer-app.yaml
kubectl apply -f 30-observer-ns.yaml
kubectl apply -f 31-observer-app.yaml
kubectl apply -f 90-vizualizer-ns.yaml
kubectl apply -f 91-vizualizer-ui.yaml

# Check what we have in terms of objects so far
for i in backend frontend client vizualizer; do echo -e "#\n# NS: $i\n#\n"; kubectl get pods,svc -n $i ; done

# Now, open a browser tab and navigate to http://<control-plane>:30001

# This is how the things look like when there aren't any network policies in place

# We don't like it this way! Instead, we want to have the following:
# 1) observer/client (OB) -> consumer/frontend (CO) -> producer/backend (PR)
# 2) vizualizer to be able to connect to all of them (we want to see the nice vizualizaton)

# For this, we must execute a set of steps

# Deploy a default deny policy in the backend, frontend, and client namespaces 
kubectl apply --namespace backend -f np-1-default-deny.yaml
kubectl apply --namespace frontend -f np-1-default-deny.yaml
kubectl apply --namespace client -f np-1-default-deny.yaml

# Return to the browser and refresh (a few times)

# Everything is gone

# Let's tackle this with the client first. Deploy an ingress policy
kubectl apply --namespace client -f np-2-allow-viz.yaml

# Return to the browser and refresh (a few times)

# A bouncing hexagon appeared. Not much, but it is at least something

# Let's deploy an ingress policy in the backend namespace as well
kubectl apply --namespace backend -f np-2-allow-viz.yaml

# And then an ingress policy in the frontend namespace as well
kubectl apply --namespace frontend -f np-2-allow-viz.yaml

# Return to the browser and refresh (a few times)

# Finally, we can see all components but without communication between them

# Let's start building the communication chain

# Open the communication PR <- CO
kubectl apply -f np-3-allow-pr-from-co.yaml

# Return to the browser and refresh (a few times)

# Okay, we are moving in the right direction

# Open the communication CO <- OB
kubectl apply -f np-4-allow-co-from-ob.yaml

# Return to the browser and refresh (a few times)

# Yes, we did it! :)

# Clean up
kubectl delete ns vizualizer client frontend backend