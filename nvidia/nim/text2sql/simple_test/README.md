# Nvidia Inference Microservice(NIM) text2sql simple test
This procedure is for testing Text2SQL model easily.

## Prerequisite
- Kubernetes platform
- NGC access token
- A GPU(over 16GB VRAM)
- PostgreSQL server which is imported [DVD rental sample data](https://neon.tech/postgresql/postgresql-getting-started/postgresql-sample-database)
- Jupyter Notebook

My environment overview is below.

```
                                                                     
    ┌──────────────────────────────────────────────────────────┐     
    │                           ┌───────────────┐              │     
    │                           │               │              │     
    │                           │               │              │     
    │                         ┌─►  PostgreSQL   │              │     
    │ ┌───────────────┐       │ │               │              │     
    │ │               │       │ │               │              │     
    │ │               ┼───────┤ └───────────────┘              │     
    │ │ Jupyter       │       │ ┌───────────────┐              │     
    │ │      Notebook │       │ │               │              │     
    │ │               │       │ │      NIM      │              │     
    │ └───────────────┘       │ │   Llama-3-    │  ┌─────────┐ │     
    │                         └─►    SQLCoder-8B├──┤  GPU    │ │     
    │                           │               │  └─────────┘ │     
    │                           └───────────────┘              │     
    │                                                          │     
    │            Kubernetes with Nvidia GPU Operator           │     
    └──────────────────────────────────────────────────────────┘     
                                                              
```

I'm using **[CNPG](https://cloudnative-pg.io/docs/)** to deploy PostgreSQL server onto kubernetes.
If you don't use *CNPG*, you can deploy it from [helm chart](https://artifacthub.io/packages/helm/bitnami/postgresql) as another way. 
The manifest for CNPG PostgreSQL is [here](postgresql.yaml). The default username is *admin* and password is *password*. 

## Test Flow

```                                                              
                                                              NIM     
    PostgreSQL              Jupyter Notebook               (Text2SQL) 
        │                          │                           │      
        │                          │    Post data related      │      
        │                          │  questions with prompt.   │      
        │                          │   ──────────────────────► │      
        │                          │                           │     
        │                          │                           │      
        │                          │    Response PostgreSQL    │      
        │                          │            query.         │      
        │                          │   ◄─────────────────────  │      
        │   Executing the query    │                           │      
        │        model generated.  │                           │      
        │ ◄─────────────────────   │                           │      
        │                          │                           │      
        │ Response query result.   │                           │      
        │ ──────────────────────►  │                           │      
        │                          │                           │      
        │                          │   Post query result with  │      
        │                          │      original question    │      
        │                          │   to get NL answer.       │      
        │                          │   ──────────────────────► │      
        │                          │                           │      
        │                          │                           │      
        │                          │   Response answer         │      
        │                          │      (NOT SQL Query)      │      
        │                          │   ◄─────────────────────  │      
        │                          │                           │      
                                                                     
```

After get result from database server, posting that data and new question with original question to get Natural Language answer against original question.
But it will be better to use general LLM model. I didn't have enough GPU resource in this experiment.

## K8s manifest to run Text2SQL model in NIM architecture
First of all, store NGC access token as a *secret* to access Nvidia registry.
This token is needed next step as well.
If you don't know how to get the access token from Nvidia, you can ask it to [ChatGPT](https://chatgpt.com/?q=How%20to%20get%20an%20access%20token%20for%20Nvidia%20NGC%20container%20registry).

```bash
kubectl create secret docker-registry nvidia-registry -n YOUR-NAMESPACE\ 
  --docker-server=nvcr.io  \
  --docker-username='$oauthtoken' \
  --docker-password=YOUR-NGC-TOKEN
```

K8s manifest for NIM *llama-3-sqlcoder-8b* model is [here](nim.yaml).
Insert your NGC token into this manifest.
And if you dont have *ingress controller*, remove that section.

```yaml
env:
- name: NGC_API_KEY
  value: '' # YOUR NGC ACCESS TOKEN
```

After inserting NGC token, you can run the *llama-3-sqlcoder-8b* model service.

```bash
$ kubectl apply -f nim.yaml -n YOUR-NAMESPACE

$ kubectl get pod
NAME                                 READY   STATUS    RESTARTS        AGE
dvd-postgresql-1                     2/2     Running   0               5h30m
llama3-sqlcoder8b-5c68b6f5d5-hhk62   2/2     Running   2 (7h15m ago)   7h16m
```

After running the *llama-3-sqlcoder-8b* model service, you can check OpenAPI schemas defined by NIM from http://\<NIM-POD-ACCESS-URL\>/docs. It looks like same as OpenAI interface.

## Test from Jupyter notebook
The jupyter notebook is [here](test2sql_dvdrental_simple_test.ipynb).
Dont forget to change some values depended your environment.

## Result example
You can see final answer in jupyter notebook like below.

```bash
[Question]
 Popular dvd titles top5

[Generated query from defog/llama-3-sqlcoder-8b]
 SELECT f.title, COUNT(r.rental_id) AS total_rentals FROM film f JOIN film_category fc ON f.film_id = fc.film_id JOIN category c ON fc.category_id = c.category_id JOIN inventory i ON f.film_id = i.film_id JOIN rental r ON i.inventory_id = r.inventory_id GROUP BY f.title ORDER BY total_rentals DESC LIMIT 5;

[Query Result]
 [{'title': 'Bucket Brotherhood', 'total_rentals': 34}, {'title': 'Rocketeer Mother', 'total_rentals': 33}, {'title': 'Grit Clockwork', 'total_rentals': 32}, {'title': 'Forward Temple', 'total_rentals': 32}, {'title': 'Juggler Hardly', 'total_rentals': 32}]


[Answer from defog/llama-3-sqlcoder-8b]
Based on the data, the top 5 most popular DVD titles are:

1. Bucket Brotherhood (34 rentals)
2. Rocketeer Mother (33 rentals)
3. Grit Clockwork (32 rentals)
4. Forward Temple (32 rentals)
5. Juggler Hardly (32 rentals)

These titles have had the most rentals, according to the data provided.
```

In some cases, SQL query may be failed.
Because Text2SQL model can not get the database details in this test. (just passing data from langchain table_info method)
If you want to improve accuracy etc, It will be good to prepare RAG to store more database details and so on.