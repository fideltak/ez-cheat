# NIM Operator Introduction

## Prerequisites
- Kubernetes environment with storage and Nvidia GPUs.
- Helm command available
- NGC API token

## Reference
- [NIM Operator Documentation](https://docs.nvidia.com/nim-operator/latest)

## Installation
First of all, add NGC helm repo into your helm environment such as laptop. 

```bash
$ helm repo add nvidia-ngc https://helm.ngc.nvidia.com/nvidia 
$ helm repo update
```

Check NIM operator version and chart.

```bash
$ helm search repo nvidia-ngc                                  
NAME                                	CHART VERSION	APP VERSION	DESCRIPTION                                       
nvidia-ngc/cuopt                    	24.03.00     	24.03.00   	NVIDIA cuOpt enables routing optimization         
nvidia-ngc/cybersecurity-dfp        	0.2.1        	23.07      	Helm chart to deploy the Morpheus Digital Finge...
nvidia-ngc/cybersecurity-sp         	0.1.0        	23.07      	Helm chart to deploy the Morpheus Spear Phishin...
nvidia-ngc/deepstream-its           	0.2.0        	1.0        	A Helm chart for Kubernetes                       
nvidia-ngc/ds-face-mask-detection   	1.0.0        	1.2        	A Helm chart for Deepstream Intelligent Video A...
nvidia-ngc/ds-lipactivity           	0.0.1        	0.0.1      	DS Lip activity                                   
nvidia-ngc/fed-svr-3                	0.9.0        	1.0        	Federated Learning HELM Chart                     
nvidia-ngc/fed-wrk-3                	0.9.0        	1.0        	Federated learning worker HELM Chart              
nvidia-ngc/gpu-operator             	v24.9.0      	v24.9.0    	NVIDIA GPU Operator creates/configures/manages ...
nvidia-ngc/k8s-nim-operator         	1.0.0        	1.0.0      	NVIDIA NIM Operator creates/configures/manages ...
nvidia-ngc/network-operator         	24.7.0       	v24.7.0    	Nvidia network operator                           
nvidia-ngc/nvidia-device-plugin     	0.9.0        	0.9.0      	A Helm chart for the nvidia-device-plugin on Ku...
nvidia-ngc/nvsm                     	1.0.1        	1.0.1      	A Helm chart for deploying Nvidia System Manage...
nvidia-ngc/tensorrt-inference-server	1.0.0        	1.0        	TensorRT Inference Server                         
nvidia-ngc/tensorrtinferenceserver  	1.0.0        	1.0        	Triton Inference Server Helm Chart                
nvidia-ngc/tritoninferenceserver    	1.0.0        	1.0        	Triton Inference Server Helm Chart                
nvidia-ngc/tritoninferenceserver_aws	0.1.0        	1.16.0     	A Helm chart for Kubernetes                       
nvidia-ngc/video-analytics-demo     	0.1.9        	1.2        	A Helm chart for Deepstream Intelligent Video A...
nvidia-ngc/video-analytics-demo-l4t 	0.1.3        	0.1.3      	Deepstream Intelligent Video Analytics Helm Cha...

$ helm show values nvidia-ngc/k8s-nim-operator >> helm_nvidia-ngc_k8s-nim-operator_1.0.0.yaml 

$ cat helm helm_nvidia-ngc_k8s-nim-operator_1.0.0.yaml 
```

*NIM operator* seems to need **Node Feature Discovery(NFD)**. If you didn't install *NFD*, you can install it with *GPU operator*.

### GPU operator
Create namespace for *GPU operator*.

```bash
$ kubectl create namespace gpu-operator
```

Then install GPU operator via helm command.

```bash
$ helm install gpu-operator nvidia-ngc/gpu-operator -n gpu-operator
```

Some *NFD* pods are running on nodes as daemonset after few minutes.

```bash
$ kubectl get pod -n gpu-operator                    
NAME                                                          READY   STATUS    RESTARTS   AGE
gpu-operator-5b4d76c556-5s5j2                                 1/1     Running   0          13m
gpu-operator-node-feature-discovery-gc-7f546fd4bc-vk4lz       1/1     Running   0          13m
gpu-operator-node-feature-discovery-master-8448c8896c-gmjd9   1/1     Running   0          13m
gpu-operator-node-feature-discovery-worker-j6qfg              1/1     Running   0          13m
gpu-operator-node-feature-discovery-worker-kn65z              1/1     Running   0          13m

$ kubectl api-resources |grep -i nodefeature
nodefeaturegroups                   nfg                      nfd.k8s-sigs.io/v1alpha1            true         NodeFeatureGroup
nodefeaturerules                    nfr                      nfd.k8s-sigs.io/v1alpha1            false        NodeFeatureRule
nodefeatures                                                 nfd.k8s-sigs.io/v1alpha1            true         NodeFeature
```

### NIM operator
Create namespace for *NIM operator* on your kubernetes environment.

```bash
$ kubectl create namespace nim-operator
```

Then install GPU operator via helm command.

```bash
$ helm install nim-operator nvidia-ngc/k8s-nim-operator -n nim-operator 
```

Confirm a *NIM operator* pod is running after few minutes.

```bash
$ kubectl get pod -n nim-operator      
NAME                                             READY   STATUS    RESTARTS   AGE
nim-operator-k8s-nim-operator-67c944f88b-skmgs   2/2     Running   0          66s
```

You can see some *Custom Resouce Definitions(CRD)* for NIM now.  
Let's check these *CRDs* in next section.

```bash
$ kubectl api-resources |grep -i nvidia     
nimcaches                                                    apps.nvidia.com/v1alpha1            true         NIMCache
nimpipelines                                                 apps.nvidia.com/v1alpha1            true         NIMPipeline
nimservices                                                  apps.nvidia.com/v1alpha1            true         NIMService
clusterpolicies                                              nvidia.com/v1                       false        ClusterPolicy
nvidiadrivers                       nvd,nvdriver,nvdrivers   nvidia.com/v1alpha1                 false        NVIDIADriver
```

## NIM CRDs
Create a namespace to deploy *NIM* later and store NGC token in that namespace.

```bash
$ kubectl create namespace nim-service

$ kubectl create secret -n nim-service docker-registry ngc-secret \
    --docker-server=nvcr.io \
    --docker-username='$oauthtoken' \
    --docker-password=<YOUR-NGC-API-TOKEN>

$ kubectl create secret -n nim-service generic ngc-api-secret \
    --from-literal=NGC_API_KEY=<YOUR-NGC-API-TOKEN>

$ kubectl get secret -n nim-service                                                                                                                                
NAME             TYPE                             DATA   AGE
ngc-api-secret   Opaque                           1      9s
ngc-secret       kubernetes.io/dockerconfigjson   1      15s
```

### nimcaches
Check current *nimcaches* objects just in case.

```bash
$ kubectl get nimcaches -n nim-service 
No resources found in nim-service namespace.
```


Let's make *nimcahche* for the model **llama-3-sqlcoder-8b**. [This](nim-cache-llama-3-sqlcoder-8b.yaml) is the manifest.  
After applying for the manifest, a pod is running. This pod seems to extract the [model profiles](https://docs.nvidia.com/nim/large-language-models/latest/profiles.html) to a configmap. 

```bash
$ kubectl apply -f nim-cache-llama-3-sqlcoder-8b.yaml -n nim-service
$ kubectl get nimcache                                              
NAME                  STATUS     PVC   AGE
llama-3-sqlcoder-8b   NotReady         25s

$ kubectl get pod -n nim-service                     
NAME                      READY   STATUS              RESTARTS   AGE
llama-3-sqlcoder-8b-pod   0/1     ContainerCreating   0          101s

$ kubectl get cm -n nim-service                                   
NAME                           DATA   AGE
kube-root-ca.crt               1      5h13m
llama-3-sqlcoder-8b-manifest   1      7m54s <= model profiles
```

And then a job pod will run to optimize the NIM services based on each model profile definitions. This task will takes few minutes. If you use a custom *deployment* manifest for NIM you create like [this](../text2sql/simple_test/nim.yaml ), it will takes long time to download model and optimizing etc for NIM service.

```bash
$ kubectl get pod -n nim-service                                
NAME                            READY   STATUS      RESTARTS   AGE
llama-3-sqlcoder-8b-job-mr658   0/1     Completed   0          7m40s

$ kubectl get nimcache -n nim-service                      
NAME                  STATUS   PVC                   AGE
llama-3-sqlcoder-8b   Ready    llama-3-sqlcoder-8b   11m
```

## nimservices 
To deploy NIM service, we can use the CRD *nimservices*. [This](nim-service-llama-3-sqlcoder-8b.yaml) is the manifest.  

```bash
$ kubectl get pod                                     
NAME                                   READY   STATUS    RESTARTS   AGE
llama-3-sqlcoder-8b-5fbcbb6c54-nz2rd   1/1     Running   0          3m15s
```

Check the service health by connecting health endpoit.

```bash
$ kubectl get svc                                                  
NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
llama-3-sqlcoder-8b   ClusterIP   10.102.128.159   <none>        8000/TCP   5m13s

$ kubectl port-forward  svc/llama-3-sqlcoder-8b 8000:8000                   
Forwarding from 127.0.0.1:8000 -> 8000
Forwarding from [::1]:8000 -> 8000
```

Open new terminal and connecting to below URI.

```bash
$ curl http://localhost:8000/v1/health/ready
{"object":"health.response","message":"Service is ready."}
```
