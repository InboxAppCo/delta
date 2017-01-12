## Extend Delta
Most of Delta can be extended and validated with custom logic using the various hooks provided.  These are custom functions that are executed in reaction to certain events.

### Path Filter
Many of the hooks rely on filtering specific paths.  Delta provides a simple syntax for describing the path you wish to match.

##### Syntax
```
"+" - wildcard
"." - nested path
```

##### Examples
```
"my.custom.path"
"my.custom.+"
"my.+.+"
```
Hopefully this will make more sense with the use cases below

### Write Interceptor  
Write interceptors allow for mutations to be modified before they are written. They come in handy when trying to reduce duplication of complex logic across various client platforms or injecting variables from the server for security reasons. It's important to note that modifications to mutation will not also be run through interceptors or validators to avoid confusing recursion scenarios.

#### Example
This is an interceptor that intercepts writes to a user's gender and also that stores a list of users by gender.  It takes the original `mutation` and combines it with another one.  The entire new mutation will be written in a single transaction.

##### Initial Mutation
```javascript
{
	"$merge": {
		"user": {
			"dummy": {
				"gender": "male"
			}
		}
	}
}
```
##### Interceptor
```go
result.InterceptWrite("user.+", func(session *Session, atom *mutation.Atom, mut *mutation.Mutation) error {
	target := atom.Path[1]
	gender := atom.Merge["gender"]
	mut.Set(true, "gender", gender, target)
	return nil
})
```

##### Matched Atom
```javascript
{
	"Path": ["user", "dummy"],
	"Merge": {
		"gender": "male"
	}
}
```
##### Resulting Mutation
```javascript
{
	"$merge": {
		"user": {
			"dummy": {
				"gender": "male"
			}
		},
		"gender": {
			"male": {
				"dummy": true
			}
		}
	}
}
```
#### What is an Atom?
In the callback function there are two parameters passed, `atom` and `mutation`.  The `mutation` is the original, full mutation that starts at the root.

The `atom` contains both a Path and a Mutation.  The mutation here only includes the subsection of the original mutation that matched the Path Filter: `userWatch.+`.  It is provided for convenience so you can extract fields without having to search deeply in the original `mutation`.
