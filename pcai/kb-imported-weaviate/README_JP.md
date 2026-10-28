[English](./README.md)

# Knowledge Base with imported Weaviate
**202607バージョンで検証**

Knowledge Baseで共有Weaviateでなく、インポートしたWeaviateを利用する方法を記載しています。

## 手順

### Weaviateのインポート
Weaviateのインポートについては[HPE GitHub](https://github.com/ai-solution-eng/frameworks)を利用できます。

### k8sカスタムリソースの作成
HPE AI EssentialsはベクタストアのためのCRDを用意しており、このCRDを活用してインポートしたWeaviateをHPE AI Essentialsに登録します。

```
$ kubectl explain --recursive vectorstores.genai.hpe.com
GROUP:      genai.hpe.com
KIND:       VectorStore
VERSION:    v1alpha1

DESCRIPTION:
    VectorStore is the Schema for the vectorstores API.
    It represents a connection to an external vector database used for storing
    and querying vector embeddings. VectorStore supports multiple providers
    including Milvus, Pinecone, and Weaviate.

FIELDS:
  apiVersion    <string>
  kind  <string>
  metadata      <ObjectMeta>
    annotations <map[string]string>
    creationTimestamp   <string>
    deletionGracePeriodSeconds  <integer>
    deletionTimestamp   <string>
    finalizers  <[]string>
    generateName        <string>
    generation  <integer>
    labels      <map[string]string>
    managedFields       <[]ManagedFieldsEntry>
      apiVersion        <string>
      fieldsType        <string>
      fieldsV1  <FieldsV1>
      manager   <string>
      operation <string>
      subresource       <string>
      time      <string>
    name        <string>
    namespace   <string>
    ownerReferences     <[]OwnerReference>
      apiVersion        <string> -required-
      blockOwnerDeletion        <boolean>
      controller        <boolean>
      kind      <string> -required-
      name      <string> -required-
      uid       <string> -required-
    resourceVersion     <string>
    selfLink    <string>
    uid <string>
  spec  <Object> -required-
    authSecret  <Object> -required-
      name      <string>
    description <string>
    vectordb    <Object> -required-
      config    <Object> -required-
      provider  <string> -required-
      enum: milvus, pinecone, weaviate
  status        <Object>
    conditions  <[]Object>
      lastTransitionTime        <string> -required-
      message   <string> -required-
      observedGeneration        <integer>
      reason    <string> -required-
      status    <string> -required-
      enum: True, False, Unknown
      type      <string> -required-
    message     <string>
    metadata    <Object>
    observedGeneration  <integer>
    observedSecretResourceVersion       <string>
    state       <string>
    enum: Ready, InProgress, Failed, Deleting
```

カスタムリソースを[サンプルのYAML](sample.yaml)を利用して作成してください。

```bash
kubectl apply -f sample.yaml
```

作成後、インポートしたWeaviateが見えるか確認します。

```bash
kubectl get vectorstores -n ezai-services
```

```
NAME                PROVIDER   STATE   AGE
chemical-nemotron   pinecone   Ready   125d
local-weaviate      weaviate   Ready   152d
my-weaviate         weaviate   Ready   17h  <-- This one.
```

HPE AI Essentialsダッシュボードでも確認できます。

![](./pics/aie01.png)

### インポートしたWeaviateを使ったKB作成
*Selected external DB(s)*項目にインポートしたWeaviateが選択できるようになっています。

![](./pics/kb01.png)