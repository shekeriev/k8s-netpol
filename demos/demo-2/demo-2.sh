#
# Demo 2
# 
# Inspired by:
# - MesosCon 2015 demo: https://github.com/mesosphere/star
# - Calico demo (based on the above): https://docs.projectcalico.org/security/tutorials/kubernetes-policy-demo/kubernetes-demo 
# 
# Modified / partially rewritten.
# The resulting code and all supporting files will be published here: https://github.com/shekeriev
# 

# Let's create the next plot from a set of manifest files
kubectl apply -f 01-ns-application.yaml
kubectl apply -f 02-dp-database.yaml
kubectl apply -f 03-dp-backend.yaml
kubectl apply -f 04-dp-frontend.yaml
kubectl apply -f 05-ns-client.yaml
kubectl apply -f 06-dp-client.yaml
kubectl apply -f 90-viz-ns.yaml
kubectl apply -f 91-viz-ui.yaml

# Check what we have in terms of objects so far
for i in application client vizualizer; do echo -e "#\n# NS: $i\n#\n"; kubectl get pods,svc -n $i ; done

# Now, open a browser tab and navigate to http://<control-plane>:30001

# This is how the things look like when there aren't any network policies in place

# We don't like it this way! Instead, we want to have the following:
# 1) client (CL) -> frontend (FE) -> backend (BE) -> database (DB)
# 2) vizualizer to be able to connect to all of them (we want to see the nice vizualizaton)

# For this, we must execute a set of steps

# Deploy a default deny policy in the application and client namespaces 
kubectl apply --namespace application -f np-1-default-deny.yaml
kubectl apply --namespace client -f np-1-default-deny.yaml

# Return to the browser and refresh (a few times)

# Everything is gone

# Let's tackle this with the client first. Deploy an ingress policy
kubectl apply --namespace client -f np-2-allow-viz.yaml

# Return to the browser and refresh (a few times)

# A bouncing hexagon appeared. Not much, but it is at least something

# Let's deploy an ingress policy in the application namespace as well
kubectl apply --namespace application -f np-2-allow-viz.yaml

# Return to the browser and refresh (a few times)

# Finally, we can see all components but without communication between them

# Let's start building the communication chain

# Open the communication BE -> DB
kubectl apply -f np-3-allow-db-from-be.yaml

# Return to the browser and refresh (a few times)

# Okay, we are moving in the right direction

# Open the communication FE -> BE
kubectl apply -f np-4-allow-be-from-fe.yaml

# Return to the browser and refresh (a few times)

# Almost there

# Open the communication CL -> FE
kubectl apply -f np-5-allow-fe-from-cl.yaml

# Return to the browser and refresh (a few times)

# Yes, we did it! :)

# Clean up
kubectl delete -f 90-viz-ns.yaml
kubectl delete -f 05-ns-client.yaml
kubectl delete -f 01-ns-application.yaml