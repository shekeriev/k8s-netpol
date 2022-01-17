#
# Demo 1
# 

#
# Setup the plot: Create the namespaces
#
kubectl create namespace ns1
kubectl label namespace ns1 name=ns1
kubectl create namespace ns2
kubectl label namespace ns2 name=ns2

#
# Setup the plot: Create a the main workload (ns1)
#
kubectl create deployment oracle --image=shekeriev/k8s-oracle:extended --namespace ns1
kubectl expose deployment oracle --port=5000 --namespace ns1

#
# Setup the plot: Create one additional workload (ns2)
#
kubectl create deployment prophet --image=shekeriev/k8s-oracle:extended --namespace ns2
kubectl expose deployment prophet --port=5000 --namespace ns2

#
# Setup the plot: Create one additional workload (default)
#
kubectl create deployment prophet --image=shekeriev/k8s-oracle:extended --namespace default
kubectl expose deployment prophet --port=5000 --namespace default

#
# Setup the plot: Create two observer/client pods (ns1)
#
kubectl run observer1 --image=alpine --namespace ns1 -- sleep 1d
kubectl label pod observer1 --namespace ns1 access=true
kubectl exec -it observer1 --namespace ns1 -- apk add curl
kubectl run observer2 --image=alpine --namespace ns1 -- sleep 1d
kubectl label pod observer2 --namespace ns1 access=false
kubectl exec -it observer2 --namespace ns1 -- apk add curl

# Check the resources we have so far (ns1)
kubectl get pods,svc --namespace ns1
kubectl get pods --namespace ns1 --show-labels

#
# Setup the plot: Create two observer/client pods (ns2)
#
kubectl run observer1 --image=alpine --namespace ns2 -- sleep 1d
kubectl label pod observer1 --namespace ns2 access=false
kubectl exec -it observer1 --namespace ns2 -- apk add curl
kubectl run observer2 --image=alpine --namespace ns2 -- sleep 1d
kubectl label pod observer2 --namespace ns2 access=true
kubectl exec -it observer2 --namespace ns2 -- apk add curl

# Check the resources we have so far (ns2)
kubectl get pods --namespace ns2 --show-labels

#
# Setup the plot: Create one more observer/client pod (default)
#
kubectl run observer1 --image=alpine --namespace default -- sleep 1d
kubectl label pod observer1 --namespace default access=true
kubectl exec -it observer1 --namespace default -- apk add curl

# Check the resources we have so far (default)
kubectl get pods --namespace default --show-labels

# 
# Check the connectivity without any policies (ingress)
# 
# observer1 (ns1) -> oracle (ns1)
kubectl exec -it observer1 --namespace ns1 -- curl --connect-timeout 5 http://oracle:5000/plain
# observer2 (ns1) -> oracle (ns1)
kubectl exec -it observer2 --namespace ns1 -- curl --connect-timeout 5 http://oracle:5000/plain
# observer1 (ns2) -> oracle (ns1)
kubectl exec -it observer1 --namespace ns2 -- curl --connect-timeout 5 http://oracle.ns1:5000/plain
# observer2 (ns2) -> oracle (ns1)
kubectl exec -it observer2 --namespace ns2 -- curl --connect-timeout 5 http://oracle.ns1:5000/plain
# observer1 (default) -> oracle (ns1)
kubectl exec -it observer1 --namespace default -- curl --connect-timeout 5 http://oracle.ns1:5000/plain

# 
# Check the connectivity without any policies (egress)
# 
# oracle (ns1) -> prophet (ns2)
POD=$(kubectl get pods --namespace ns1 --selector=app=oracle -o jsonpath='{ .items[0].metadata.name }')
kubectl exec -it $POD --namespace ns1 -- curl --connect-timeout 5 http://prophet.ns2:5000/plain
# oracle (ns1) -> prophet (default)
kubectl exec -it $POD --namespace ns1 -- curl --connect-timeout 5 http://prophet.default:5000/plain

# As there are no policies, both ingress and egress should work
# We should be able to see answers from the applications

# Create a simple network policy that will allow incoming connections (ingress)
# to our pod only for pods that are labeled in a certain way (access=true)
cat > access-oracle.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: access-oracle
  namespace: ns1
spec:
  podSelector:
    matchLabels:
      app: oracle
  ingress:
  - from:
    - podSelector:
        matchLabels:
          access: "true"
EOF

# Deploy it
kubectl apply -f access-oracle.yaml

# 
# Check the ingress connectivity after the policy has been deployed
# 
# observer1 (ns1) -> oracle (ns1)
kubectl exec -it observer1 --namespace ns1 -- curl --connect-timeout 5 http://oracle:5000/plain
# observer2 (ns1) -> oracle (ns1)
kubectl exec -it observer2 --namespace ns1 -- curl --connect-timeout 5 http://oracle:5000/plain
# observer1 (ns2) -> oracle (ns1)
kubectl exec -it observer1 --namespace ns2 -- curl --connect-timeout 5 http://oracle.ns1:5000/plain
# observer2 (ns2) -> oracle (ns1)
kubectl exec -it observer2 --namespace ns2 -- curl --connect-timeout 5 http://oracle.ns1:5000/plain
# observer1 (default) -> oracle (ns1)
kubectl exec -it observer1 --namespace default -- curl --connect-timeout 5 http://oracle.ns1:5000/plain

# Only one successful attempt - observer1 (ns1) -> oracle (ns1)
# Why? Others with the same labels?

# Ask for details about the policy we just created
kubectl describe netpol --namespace ns1

# Explore the From section
# Aha, here is the answer

# But how to allow communication from pods in other namespaces?
# For starters, we can allow all pods from a namespce (ns2). Let's do it

# Extend the policy to allow incoming connections (ingress) to our pod 
# also for pods that are part of a particular namespace (ns2)
cat > access-oracle.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: access-oracle
  namespace: ns1
spec:
  podSelector:
    matchLabels:
      app: oracle
  ingress:
  - from:
    - podSelector:
        matchLabels:
          access: "true"
    - namespaceSelector:
        matchLabels:
          name: "ns2"
EOF

# Deploy it
kubectl apply -f access-oracle.yaml

# 
# Check the ingress connectivity after the policy has been deployed
# 
# observer1 (ns1) -> oracle (ns1)
kubectl exec -it observer1 --namespace ns1 -- curl --connect-timeout 5 http://oracle:5000/plain
# observer2 (ns1) -> oracle (ns1)
kubectl exec -it observer2 --namespace ns1 -- curl --connect-timeout 5 http://oracle:5000/plain
# observer1 (ns2) -> oracle (ns1)
kubectl exec -it observer1 --namespace ns2 -- curl --connect-timeout 5 http://oracle.ns1:5000/plain
# observer2 (ns2) -> oracle (ns1)
kubectl exec -it observer2 --namespace ns2 -- curl --connect-timeout 5 http://oracle.ns1:5000/plain
# observer1 (default) -> oracle (ns1)
kubectl exec -it observer1 --namespace default -- curl --connect-timeout 5 http://oracle.ns1:5000/plain

# As expected. All pods from ns2 can connect to our pod in ns1
# No changes with pods in ns1 and default namespaces

# Ask for details about the the deployed policies
kubectl describe netpol -n ns1

# Explore the two From sections

# What if we want to allow connections from pods with label access=true 
# from all namespaces? Maybe, we should just change the namespaceSelector?
# Let's do it
cat > access-oracle.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: access-oracle
  namespace: ns1
spec:
  podSelector:
    matchLabels:
      app: oracle
  ingress:
  - from:
    - podSelector:
        matchLabels:
          access: "true"
    - namespaceSelector: {}
EOF

# Deploy it
kubectl apply -f access-oracle.yaml

# 
# Check the ingress connectivity after the policy has been deployed
# 
# observer1 (ns1) -> oracle (ns1)
kubectl exec -it observer1 --namespace ns1 -- curl --connect-timeout 5 http://oracle:5000/plain
# observer2 (ns1) -> oracle (ns1)
kubectl exec -it observer2 --namespace ns1 -- curl --connect-timeout 5 http://oracle:5000/plain
# observer1 (ns2) -> oracle (ns1)
kubectl exec -it observer1 --namespace ns2 -- curl --connect-timeout 5 http://oracle.ns1:5000/plain
# observer2 (ns2) -> oracle (ns1)
kubectl exec -it observer2 --namespace ns2 -- curl --connect-timeout 5 http://oracle.ns1:5000/plain
# observer1 (default) -> oracle (ns1)
kubectl exec -it observer1 --namespace default -- curl --connect-timeout 5 http://oracle.ns1:5000/plain

# Not quite as expected. 
# All pods from all namespaces can connect to our pod in ns1. Why?

# Ask for details about the current state of our policy
kubectl describe netpol -n ns1

# Explore the two From sections
# Aha, here is the answer

# We should correct this as currently our pod is open as if there isn't any policy

# Let's do it by changing the OR to AND
cat > access-oracle.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: access-oracle
  namespace: ns1
spec:
  podSelector:
    matchLabels:
      app: oracle
  ingress:
  - from:
    - podSelector:
        matchLabels:
          access: "true"
      namespaceSelector: {}
EOF

# Deploy it
kubectl apply -f access-oracle.yaml

# 
# Check the ingress connectivity after the policy has been deployed
# 
# observer1 (ns1) -> oracle (ns1)
kubectl exec -it observer1 --namespace ns1 -- curl --connect-timeout 5 http://oracle:5000/plain
# observer2 (ns1) -> oracle (ns1)
kubectl exec -it observer2 --namespace ns1 -- curl --connect-timeout 5 http://oracle:5000/plain
# observer1 (ns2) -> oracle (ns1)
kubectl exec -it observer1 --namespace ns2 -- curl --connect-timeout 5 http://oracle.ns1:5000/plain
# observer2 (ns2) -> oracle (ns1)
kubectl exec -it observer2 --namespace ns2 -- curl --connect-timeout 5 http://oracle.ns1:5000/plain
# observer1 (default) -> oracle (ns1)
kubectl exec -it observer1 --namespace default -- curl --connect-timeout 5 http://oracle.ns1:5000/plain

# Finally. All pods with label access=true from all namespaces can connect to our pod and others cannot

# Ask for details about the current state of our policy
kubectl describe netpol -n ns1

# Explore the From section

# So, a single dash may change how the policy is understood by the cluster...
# We also confirmed that the lists (ingress in our case) are additive. On top of this, we managed to change OR to AND

# One more statement to confirm - the policies are additive as well. Are they?
# And what about the egress rules?

# Let's create an egress policy that will allow access only to pods in certain namespace (ns2)
cat > access-oracle2.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: access-oracle2
  namespace: ns1
spec:
  podSelector:
    matchLabels:
      app: oracle
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: "prophet"
      namespaceSelector:
        matchLabels:
          name: "ns2"
EOF

# Deploy it
kubectl apply -f access-oracle2.yaml

# 
# Check the egress connectivity now
# 
# oracle (ns1) -> prophet (ns2)
POD=$(kubectl get pods --namespace ns1 --selector=app=oracle -o jsonpath='{ .items[0].metadata.name }')
kubectl exec -it $POD --namespace ns1 -- curl --connect-timeout 5 http://prophet.ns2:5000/plain
# oracle (ns1) -> prophet (default)
kubectl exec -it $POD --namespace ns1 -- curl --connect-timeout 5 http://prophet.default:5000/plain

# Hm, it doesn't work ... Why?
# There is a hint: 
# - now the error is: Resolving timed out after 5000 milliseconds
# - before it was: Connection timeout after 5000 ms
# But WHY?!




# It appears that our pod cannot resolve the name
# Perhaps, it cannot talk to the DNS service

# Ask for details about the current state of our policy
kubectl describe netpol -n ns1

# And yes, we caused it by limiting the egress communication just to the ns2 namespace
# DNS components are in the kube-system namespace

# Let's correct this by allowing communication also to the kube-system namespace
cat > access-oracle2.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: access-oracle2
  namespace: ns1
spec:
  podSelector:
    matchLabels:
      app: oracle
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: "prophet"
      namespaceSelector:
        matchLabels:
          name: "ns2"
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: "kube-system"
EOF

# Deploy it
kubectl apply -f access-oracle2.yaml

# 
# Check the egress connectivity now
# 
# oracle (ns1) -> prophet (ns2)
POD=$(kubectl get pods --namespace ns1 --selector=app=oracle -o jsonpath='{ .items[0].metadata.name }')
kubectl exec -it $POD --namespace ns1 -- curl --connect-timeout 5 http://prophet.ns2:5000/plain
# oracle (ns1) -> prophet (default)
kubectl exec -it $POD --namespace ns1 -- curl --connect-timeout 5 http://prophet.default:5000/plain

# Yes! We did it! :)

# Ask for details about the current state of our policy
kubectl describe netpol -n ns1

# Okay, we confirmed that policies are additive
# And we managed to see how the egress is working

# Let’s clean a bit
kubectl delete deployment prophet
kubectl delete service prophet
kubectl delete pod observer1
kubectl delete namespace ns1 ns2
