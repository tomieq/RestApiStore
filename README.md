# RestApiStore
It is simple app that stores data in SQLite and exposes Rest API for data manipulation

### How to store data
Send `POST` request with json object and the backend will prepare the database for you:
```
POST http://localhost:8080/myapp/data/people
```
body:
```json
{
    "name": "John",
    "age": 12,
    "surname": "Novak"
}
```
Underneath the backend will create a database file named `myapp.db` in the current working directory and will create `people` table with 4 columns:
- name TEXT
- age INTEGER
- surname TEXT

As response you will get json:
```json
{
    "id": 1
    "name": "John",
    "age": 12,
    "surname": "Novak"
}
```
### How to update data
Just send `POST` request with json data with `id` field set to the object you want to modify:
```
POST http://localhost:8080/myapp/data/people
```
```json
{
    "id": 1
    "name": "Tom",
    "age": 38,
    "surname": "Kowalsky"
}
```
As response you will get updated json (should be exact the same as the one in request).
### How to query data
You can query for specific object with `id`:
```
GET http://localhost:8080/myapp/data/people/1
```
As response you will get valid json response or 404 if object does not exist.
### How to get all objects
```
GET http://localhost:8080/myapp/data/people
```
Will return a list of objects in json format.
### How to filter objects
```
GET http://localhost:8080/myapp/data/people?name=Tom&age=38
```
If you want to filter objects by its properties, just add them as query params. Above example will return all objects that have name property value equal to `Tom` and age equal to `38` 
### How to check object's properties
You can check what properties are stored per object by sending request:
```
GET GET http://localhost:8080/myapp/schema/people
```
You will get json with key names and it's type:
```json
{
    "name": "string",
    "id": "int",
    "age": "int",
    "limit": "int",
    "surname": "string"
}
```
### How to extend existing model with additional properties
Just update or create a new your object with new fields:
```
POST http://localhost:8080/myapp/data/people
```
```json
{
    "id": 1
    "name": "Tom",
    "age": 38,
    "surname": "Kowalsky"
    "region": "EU"
}
```
The property `region` will be created for all existing object with value set to nil.
