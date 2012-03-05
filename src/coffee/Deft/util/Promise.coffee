###
Copyright (c) 2012 [DeftJS Framework Contributors](http://deftjs.org)
Open source under the [MIT License](http://en.wikipedia.org/wiki/MIT_License).

Promise.when(), all(), any(), map() and reduce() methods adapted from:
[when.js](https://github.com/cujojs/when)
Copyright (c) B Cavalier & J Hann
Open source under the [MIT License](http://en.wikipedia.org/wiki/MIT_License).
###

Ext.define( 'Deft.util.Promise',
	alternateClassName: [ 'Deft.Promise' ]
	
	statics:
		###*
		Returns a new {@link Deft.util.Promise} with the specified callbacks registered to be called:
		- immediately for the specified value, or
		- when the specified {@link Deft.util.Deferred} or {@link Deft.util.Promise} is resolved, rejected, updated or cancelled.
		###
		when: ( promiseOrValue, callbacks ) ->
			if promiseOrValue instanceof Ext.ClassManager.get( 'Deft.util.Promise' ) or promiseOrValue instanceof Ext.ClassManager.get( 'Deft.util.Deferred' )
				return promiseOrValue.then( callbacks )
			else
				deferred = Ext.create( 'Deft.util.Deferred' )
				deferred.resolve( promiseOrValue )
				return deferred.then( callbacks )
		
		###*
		Returns a new {@link Deft.util.Promise} that will only resolve once all the specified `promisesOrValues` have resolved.
		The resolution value will be an Array containing the resolution value of each of the `promisesOrValues`.
		###
		all: ( promisesOrValues, callbacks ) ->
			results = new Array( promisesOrValues.length )
			promise = @reduce( promisesOrValues, @reduceIntoArray, results )
			
			return @when( promise, callbacks )
		
		###*
		Returns a new {@link Deft.util.Promise} that will only resolve once any one of the the specified `promisesOrValues` has resolved.
		The resolution value will be the resolution value of the triggering `promiseOrValue`.
		###
		any: ( promisesOrValues, callbacks ) ->
			deferred = Ext.create( 'Deft.util.Deferred' )
			
			updater = ( progress ) ->
				deferred.update( progress )
				return
			resolver = ( value ) ->
				complete()
				deferred.resolve( value )
				return
			rejecter = ( error ) ->
				complete()
				deferred.reject( error )
				return
			
			complete = ->
				updater = resolver = rejecter = -> return
				
			resolveFunction  = ( value ) -> resolver( value )
			rejectFunction   = ( value ) -> rejector( value )
			progressFunction = ( value ) -> updater( value )
			
			for promiseOrValue, index in promisesOrValues
				if index of promisesOrValues
					@when( promiseOrValue, resolveFunction, rejectFunction, progressFunction )
			
			return deferred.then( callbacks )
		
		###*
		Traditional map function, similar to `Array.prototype.map()`, that allows input to contain promises and/or values.
		The specified map function may return either a value or a promise.
		###
		map: ( promisesOrValues, mapFunction ) ->
			# Since the map function may be asynchronous, get all invocations of it into flight ASAP.
			results = new Array( promisesOrValues.length )
			for promiseOrValue, index in promisesOrValues
				if index of promisesOrValues
					results[ index ] = @when( promiseOrValue, mapFunction )
				
			# Then use reduce() to collect all the results.
			return @reduce( results, @reduceIntoArray, results )
		
		###*
		Traditional reduce function, similar to `Array.reduce()`, that allows input to contain promises and/or values.
		###
		reduce: ( promisesOrValues, reduceFunction, initialValue ) ->
			# Wrap the reduce function with one that handles promises and then delegates to it.
			whenResolved = @when
			reduceArguments = [
				( previousValueOrPromise, currentValueOrPromise, currentIndex ) ->
					return whenResolved( previousValueOrPromise, ( previousValue ) ->
						return whenResolved( currentValueOrPromise, ( currentValue ) ->
							return reduceFunction( previousValue, currentValue, currentIndex, promisesOrValues )
						)
					)
			]
			
			if ( arguments.length is 3 )
				reduceArguments.push( initialValue )
			
			return @when( @reduceArray.apply( promisesOrValues, reduceArguments ) )
		
		###*
		Internal reduce implementation - includes fallback when Array.reduce is not available.
		@private
		###
		reduceArray: ( reduceFunction, initialValue ) ->
			# ES5 reduce implementation if native not available
			# See: http://es5.github.com/#x15.4.4.21 as there are many specifics and edge cases.
			# ES5 dictates that reduce.length === 1
			# This implementation deviates from ES5 spec in the following ways:
			# 1. It does not check if reduceFunc is a Callable
			index = 0
			array = Object( @ )
			length = array.length >>> 0
			args = arguments
			
			# If no initialValue, use first item of array (we know length !== 0 here) and adjust index to start at second item
			if args.length <= 1
				# Skip to the first real element in the array
				loop
					if index of array
						reduced = array[ index++ ]
						break
					# If we reached the end of the array without finding any real elements, it's a TypeError
					if ++index >= length
						throw new TypeError()
			else
				# If initialValue provided, use it
				reduced = args[ 1 ]
			
			# Do the actual reduce
			while index < length
				# Skip holes
				if index of array
					reduced = reduceFunction( reduced, array[ index ], index, array )
				index++
			
			return reduced
		
		###*
		@private
		###
		reduceIntoArray: ( previousValue, currentValue, currentIndex ) ->
			previousValue[ currentIndex ] = currentValue
			return previousValue
	
	constructor: ( deferred ) ->
		@deferred = deferred
		return @
	
	###*
	Returns a new {@link Deft.util.Promise} with the specified callbacks registered to be called when this {@link Deft.util.Promise} is resolved, rejected, updated or cancelled.
	###
	then: ( callbacks ) ->
		return @deferred.then( callbacks )
	
	###*
	Cancel this {@link Deft.util.Promise} and notify relevant callbacks.
	###
	cancel: ( reason ) ->
		return @deferred.cancel( reason )
,
	->
		# Use native reduce implementation, if available.
		if Array.prototype.reduce?
			@reduceArray = Array.prototype.reduce
		return
)