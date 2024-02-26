# Other topics

## Don't create namespace
When you create your namespace by kubectl or somthing, it will be gone after about 24hours.  
Ezmeral Unified Analytics is comsumption model based on CPU and GPU. They are monitoring metrics of the software they provided to calculate resource usages.  
So if we make a own namespace and deploy own software into it, they cannot calculate resource usages of user specific software. That's why they need to remove it from UA k8s cluster.  
If you want to deploy BYO software, use **App Import Feaure**.