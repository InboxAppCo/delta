## Queries
Fetching data out of delta is done via a Query.  A query can fetch multiple paths and supports paging via `$min`, `$max`, and `$limit` options.  The response from a query is a Mutation which can be applied to your local store or be read as a normal object

### Examples
Here are a few examples of querying

#### Simple Fetch
This will simply fetch the object at the given path. The empty object in the query signals that there is no paging you would like to do
```javascript
{
	"action": "delta.query",
	"version": 1,
	"body": {
		"user:info": {
			"coolguy": {} // Fetch everything at user:info.coolguy
		}
	}
}
```

#### Response
A `$delete` is included so you can apply this mutation to your local store and stale data will be removed before inserting this. If you are not saving it to a local store, then you can just read the data from the `$merge` field
```javascript
{
	"action": "drs.response",
	"body": {
		"$delete": {
			"user:info": {
				"coolguy": 1
			}
		},
		"$merge": {
			"user:info": {
				"coolguy": {
					"key": "coolguy",
					"name": "Cool Guy",
					"gender": "male",
				}
			}
		}
	}
}
```

#### Paging Fetch
When you need to specify a limited set of results you can take advantage of `$min`, `$max`, and `$limit`

```javascript
{
	"action": "delta.query",
	"version": 1,
	"body": {
		"user:friends": {
			"coolguy": {
				"$limit": 3
			}
		}
	}

}
```

#### Data
```javascript
{
	"action": "drs.response",
	"body": {
		"$delete": {
			"user:friends": {
				"coolguy": 1
			}
		},
		"$merge": {
			"user:friends": {
				"coolguy": {
					"coolguy1": true,
					"coolguy2": true,
					"coolguy3": true
				}
			}
		}
	}
}
```

#### Next Page
To get the next page of results for the above example you can specify the `$min` field

```javascript
{
	"action": "delta.query",
	"version": 1,
	"body": {
		"user:friends": {
			"coolguy": {
				"$min": "coolguy3",
				"$limit": 3
			}
		}
	}

}
```
#### Data
```javascript
{
	"action": "drs.response",
	"body": {
		"$delete": {
			"user:friends": {
				"coolguy": 1
			}
		},
		"$merge": {
			"user:friends": {
				"coolguy": {
					"coolguy4": true,
					"coolguy5": true,
					"coolguy6": true
				}
			}
		}
	}
}
```
