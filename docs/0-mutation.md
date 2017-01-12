## Mutations
Mutations are the fundamental way to create, update, or delete data in Delta.  A `mutation` consists of all the data to `$merge` and all the data to `$delete` in a single transaction. Deletes are always applied prior to merges.

### Examples
Here are a few examples of how mutations can be used

#### Merge Example
This will simply create a user.

```javascript
{
	"action": "delta.mutation",
	"version": 1,
	"body": {
		"$merge": {
			"user:info": {
				"coolguy": {
					"key": "coolguy",
					"name": "Cool Guy",
					"gender": "male"
				}
			}
		}
	}
}
```

#### Data
This is the resulting data that is stored
```javascript
{
	"user:info": {
		"coolguy": {
			"key": "coolguy",
			"name": "Cool Guy",
			"gender": "male"
		}
	}
}
```

#### Delete Example
To delete the user you must specify the path you want to delete. The `1` has no significance, it just signals to delta that this path and below should be deleted.
```javascript
{
	"action": "delta.mutation",
	"version": 1,
	"body": {
		"$delete": {
			"user:info": {
				"coolguy": 1
			}
		}
	}
}
```

#### Data
```javascript
{
	"user:info": {}
}
```

#### Complex Example
You can specify multiple modifications as one mutation.  Remember, `$delete` is always applied first and then `$merge`
```javascript
{
	"action": "delta.mutation",
	"version": 1,
	"body": {
		"$delete": {
			"user:info": {
				"coolguy": 1
			}
		}
		"$merge": {
			"user:info": {
				"coolguy": {
					"key": "coolguy",
					"name": "Cool Guy",
					"gender": "male",
				}
			},
			"user:friends": {
				"coolguy": {
					"coolguy2": true
				}
			}
		}
	}
}
```

#### Data
```javascript
{
	"user:info": {
		"coolguy": {
			"key": "coolguy",
			"name": "Cool Guy",
			"gender": "male",
		}
	},
	"user:friends": {
		"coolguy": {
			"coolguy2": true
		}
	}
}
```
