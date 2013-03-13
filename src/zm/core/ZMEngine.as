
//------------------------------------------------------------------------------
//  
//  Package
//  
//------------------------------------------------------------------------------

package zm.core
{
	
	//--------------------------------------------------------------------------
	//  
	//  Imports
	//  
	//--------------------------------------------------------------------------
	
	import flash.display.Loader;
	import flash.events.AsyncErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.system.ApplicationDomain;
	import flash.system.LoaderContext;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import flash.utils.Endian;
	import flash.utils.describeType;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	import zm.events.ZMErrorEvent;
	
	//--------------------------------------------------------------------------
	//  
	//  Class
	//  
	//--------------------------------------------------------------------------
	
	/**
	 * The ZombieMonkey engine encapsulates the compiled ABC binaries of the 
	 * Tamarin compiler contributed to Mozilla by Adobe.
	 */
	public final class ZMEngine extends EventDispatcher
	{
		
		//----------------------------------------------------------------------
		//  
		//  Fields
		//  
		//----------------------------------------------------------------------
		
		//------------------------------
		//  Tamarin binaries
		//------------------------------
		
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/abc.es.abc", mimeType="application/octet-stream")]
		private static const abc:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/asm.es.abc", mimeType="application/octet-stream")]
		private static const asm:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/ast.es.abc", mimeType="application/octet-stream")]
		private static const ast:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/bytes-tamarin.es.abc", mimeType="application/octet-stream")]
		private static const bytes_tamarin:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/cogen-expr.es.abc", mimeType="application/octet-stream")]
		private static const cogen_expr:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/cogen-stmt.es.abc", mimeType="application/octet-stream")]
		private static const cogen_stmt:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/cogen.es.abc", mimeType="application/octet-stream")]
		private static const cogen:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/debug.es.abc", mimeType="application/octet-stream")]
		private static const debug:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/define.es.abc", mimeType="application/octet-stream")]
		private static const define:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/emit.es.abc", mimeType="application/octet-stream")]
		private static const emit:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/esc-core.es.abc", mimeType="application/octet-stream")]
		private static const esc_core:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/esc-env.es.abc", mimeType="application/octet-stream")]
		private static const esc_env:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/eval-support.es.abc", mimeType="application/octet-stream")]
		private static const eval_support:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/lex-char.es.abc", mimeType="application/octet-stream")]
		private static const lex_char:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/lex-scan.es.abc", mimeType="application/octet-stream")]
		private static const lex_scan:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/lex-token.es.abc", mimeType="application/octet-stream")]
		private static const lex_token:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/parse.es.abc", mimeType="application/octet-stream")]
		private static const parse:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/util-tamarin.es.abc", mimeType="application/octet-stream")]
		private static const util_tamarin:Class;
		[Embed(source="../assets/tamarin-central-fbecf6c8a86f/util.es.abc", mimeType="application/octet-stream")]
		private static const util:Class;
		
		//------------------------------
		//  SWF byte assets
		//------------------------------
		
		[Embed(source="../assets/abc-header", mimeType="application/octet-stream")]
		private static const abc_header:Class;
		[Embed(source="../assets/swf-footer", mimeType="application/octet-stream")]
		private static const swf_footer:Class;
		[Embed(source="../assets/swf-header", mimeType="application/octet-stream")]
		private static const swf_header:Class;
		
		//------------------------------
		//  Internal fields
		//------------------------------
		
		private static var _allowInstantiation:Boolean;
		private var _compileStringToBytes:Function;
		private var _context:LoaderContext;
		private static var _engine:ZMEngine;
		private var _global:Dictionary;
		private var _loader:Loader;
		private var _loaders:Dictionary;
		private var _namespaces:Dictionary;
		
		//------------------------------
		//  Constants
		//------------------------------
		
		public static const BRANCH:String = "tamarin-central";
		public static const CHANGE_SET:String = "fbecf6c8a86f";
		public static const DATE:Date = new Date(2010, 3, 10, 17, 58, 52);
		public static const REVISION:uint = 714; 
		
		//----------------------------------------------------------------------
		//  
		//  Constructor Method
		//  
		//----------------------------------------------------------------------
		
		/**
		 * Constructs the ZombieMonkey engine.
		 */
		public function ZMEngine()
		{
			if (!_allowInstantiation)
			{
				throw new ArgumentError(getQualifiedClassName(this) + "$ class cannot be instantiated.", 2012);
			}
			
			// Allows the loaded SWF to access classes in the application as 
			// well as the application to access classes in the loaded SWF
			_context = new LoaderContext(false, ApplicationDomain.currentDomain);
			_context.allowCodeImport = true;
			
			_global = new Dictionary(true);
			
			_loader = new Loader();
			_loader.contentLoaderInfo.addEventListener(AsyncErrorEvent.ASYNC_ERROR, dispatchEvent, false, 0, true);
			_loader.contentLoaderInfo.addEventListener(Event.COMPLETE, handleComplete, false, 0, true);
			_loader.contentLoaderInfo.addEventListener(Event.INIT, dispatchEvent, false, 0, true);
			_loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, dispatchEvent, false, 0, true);
			_loader.contentLoaderInfo.addEventListener(Event.OPEN, dispatchEvent, false, 0, true);
			_loader.contentLoaderInfo.addEventListener(ProgressEvent.PROGRESS, dispatchEvent, false, 0, true);
			_loader.contentLoaderInfo.addEventListener(SecurityErrorEvent.SECURITY_ERROR, dispatchEvent, false, 0, true);
			_loader.contentLoaderInfo.addEventListener(Event.UNLOAD, dispatchEvent, false, 0, true);
			
			_loaders = new Dictionary();
			
			_namespaces = new Dictionary();
		}
		
		//----------------------------------------------------------------------
		//  
		//  Properties
		//  
		//----------------------------------------------------------------------
		
		//------------------------------
		//  engine
		//------------------------------
		
		/**
		 * The singleton instance of the ZMEngine.
		 */
		public static function get engine():ZMEngine
		{
			if (!_engine)
			{
				_allowInstantiation = true;
				_engine = new ZMEngine();
				_allowInstantiation = false;
			}
			
			return _engine;
		}
		
		//------------------------------
		//  isRunning
		//------------------------------
		
		/**
		 * Whether or not the ZMEngine is running.
		 */
		public function get isRunning():Boolean
		{
			return Boolean(_compileStringToBytes);
		}
		
		//----------------------------------------------------------------------
		//  
		//  Methods
		//  
		//----------------------------------------------------------------------
		
		/**
		 * Executes the bytes as an SWF, loading definitions into the current 
		 * domain. You must manually unload the bytes with the 
		 * <code>ZMEngine.kill</code> method.
		 * 
		 * @param bytes The bytes representing the SWF.
		 * @return <code>null</code> if the engine is not running or properly 
		 * loaded, otherwise a hash code representing the loaded file.
		 */
		public function exec(bytes:ByteArray):String
		{
			if (!isRunning)
			{
				// Not running, not necessary but it's nice to 
				// have everything depend on the engine running
				return null;
			}
			
			// Use current domain
			var context:LoaderContext = _context;
			
			// Store it with a unique hash code
			var hashCode:String = generateHashCode();
			var loader:Loader = new Loader();
			_loaders[hashCode] = loader;
			loader.loadBytes(bytes, context);
			
			return hashCode;
		}
		
		/**
		 * Evaluates an ES4 script.
		 * 
		 * @param script The ES4 script.
		 * @param context A named context to refer to the script's environment.
		 * @return <code>null</code> if the engine is not running or properly 
		 * loaded, otherwise a hash code representing the compiled and loaded 
		 * ABC file.
		 */
		public function eval(script:String, context:String = null):String
		{
			if (!isRunning)
			{
				// Not running
				return null;
			}
			
			// Analyze for namespace usage and store those namespaces (not foolproof)
			var pattern:RegExp = /use[ \t]+namespace[ \t](('.+?')|(".+?"))[ \t]*([;\n\r]|$)/g;
			var result:Object = pattern.exec(script);
			
			// Reset the values of each stored namespace
			for (var key:String in _namespaces)
			{
				_namespaces[key] = false;
			}
			
			// Go through and find namespaces being used
			while (result != null)
			{
				key = result[1].replace(/['"]/g, "");
				_namespaces[key] = true;
				
				result = pattern.exec(script); 
			}
			
			// Add namespaces that were previously used and not included in this context
			var directives:String = "";
			for (key in _namespaces)
			{
				directives += "use namespace '" + key + "'; ";
			}
			
			// Compile the code with modifications
			var hashCode:String = generateHashCode();
			var bytes:ByteArray;
			bytes = _compileStringToBytes("try { with ('com.zm'::ZMEngine.engine.getGlobal('" + hashCode + "')) { " + directives + script + " } } catch (error) { 'com.zm'::ZMEngine.engine.handleError('" + hashCode + "', error); } 'com.zm'::ZMEngine.engine.updateGlobal('" + hashCode + "', this); 'com.zm'::ZMEngine.engine.kill('" + hashCode + "');", context ? context : hashCode);
			bytes.position = 0;
			
			// Store it with a unique hash code
			var loader:Loader = new Loader();
			_loaders[hashCode] = loader;
			
			// Load code to run it
			loadABC(loader, new <ByteArray>[bytes]);
			
			return hashCode;
		}
		
		/**
		 * Catches an error thrown by a loaded ABC file and dispatches an 
		 * ZMErrorEvent object containing the error.
		 * 
		 * @param hashCode A hash code of a loaded ABC file.
		 * @param error The error to throw as a ZMErrorEvent.
		 */
		public function handleError(hashCode:String, error:Error):void
		{
			if (hashCode in _loaders)
			{
				dispatchEvent(new ZMErrorEvent(error));
			}
		}
		
		/**
		 * @private
		 */
		private function generateHashCode():String
		{
			var hashCode:String = "";
			
			for (var i:int = 0; i < 12; i++)
			{
				// Randomly concatenate a hexadecimal character
				hashCode += Math.floor(Math.random() * 16).toString(16);
			}
			
			return hashCode;
		}
		
		/**
		 * Returns the global object of the ZMEngine.
		 * 
		 * @param hashCode A hash code of a loaded ABC file.
		 * @return The global object of the ZMEngine.
		 */
		public function getGlobal(hashCode:String):Dictionary
		{
			return hashCode in _loaders ? _global : null;
		}
		
		/**
		 * @private
		 */
		private function loadABC(loader:Loader, abcData:Vector.<ByteArray>, useCurrentDomain:Boolean = false):void
		{
			var swf:ByteArray = new ByteArray();
			swf.endian = Endian.LITTLE_ENDIAN;
			
			// Write SWF header
			// SWF version doesn't matter, full access to all available APIs
			swf.writeBytes(new swf_header() as ByteArray);
			
			// Write all ABC data
			var abcHeader:ByteArray = new abc_header() as ByteArray;
			for each (var abc:ByteArray in abcData)
			{
				// Write ABC header
				swf.writeBytes(abcHeader, 0, 2);
				
				// Write ABC length and ABC data
				swf.writeInt(abc.length);
				swf.writeBytes(abc);
			}
			
			// Write SWF footer
			swf.writeBytes(new swf_footer() as ByteArray, 0, 2);
			
			// Write SWF length
			swf.position = 4;
			swf.writeInt(swf.length);
			
			// Reset position
			swf.position = 0;
			
			// Determine loader context
			var context:LoaderContext;
			
			if (useCurrentDomain)
			{
				context = _context;
			}
			else
			{
				context = new LoaderContext();
				context.allowCodeImport = true;
			}
			
			loader.loadBytes(swf, context);
		}
		
		/**
		 * Resets the ZMEngine. The global object is cleared of all memory 
		 * and any loaded ABC files are marked for garbage collection.
		 */
		public function reset():void
		{
			// Resets the global object
			for (var key:String in _global)
			{
				delete _global[key];
			}
			
			// Removes all loaded ABC files
			for (key in _loaders)
			{
				delete _loaders[key];
			}
			
			// Removes all loaded namespaces
			for (key in _namespaces)
			{
				delete _namespaces[key];
			}
		}
		
		/**
		 * Starts up the ZombieMonkey engine. Dispatches <code>Event.COMPLETE</code> 
		 * when the engine is ready.
		 */
		public function startup():void
		{
			// Create a vector of all ABC files for the engine
			// The order of the ABC files matters
			var abcData:Vector.<ByteArray> = new <ByteArray>[
				new debug() as ByteArray,
				new util() as ByteArray,
				new bytes_tamarin() as ByteArray,
				new util_tamarin() as ByteArray,
				new lex_char() as ByteArray,
				new lex_scan() as ByteArray,
				new lex_token() as ByteArray,
				new ast() as ByteArray,
				new define() as ByteArray,
				new parse() as ByteArray,
				new asm() as ByteArray,
				new abc() as ByteArray,
				new emit() as ByteArray,
				new cogen() as ByteArray,
				new cogen_stmt() as ByteArray,
				new cogen_expr() as ByteArray,
				new esc_core() as ByteArray,
				new eval_support() as ByteArray,
				new esc_env() as ByteArray
			];
			
			// Load ABC data in current domain
			loadABC(_loader, abcData, true);
		}
		
		/**
		 * Shuts down the ZombieMonkey engine.
		 */
		public function shutdown():void
		{
			// Clear memory
			reset();
			
			// Stop the engine
			_loader.unloadAndStop();
			
			// Reset running state
			_compileStringToBytes = null;
		}
		
		/**
		 * Unloads and garbage collects an ABC file with the given hash code.
		 * 
		 * @param hashCode The hash code assigned to the ABC file before 
		 * compilation.
		 * @return <code>true</code> if the ABC file was found and successfully 
		 * marked for garbage collection. <code>false</code> otherwise.
		 */
		public function kill(hashCode:String):Boolean
		{
			// Check to make sure the hash code is in the dictionary
			if (hashCode in _loaders)
			{
				var loader:Loader = _loaders[hashCode] as Loader;
				
				// Check to make sure the ABC file exists
				if (loader)
				{
					loader.unloadAndStop();
					return delete _loaders[hashCode];
				}
			}
			
			return false;
		}
		
		/**
		 * Updates the ZMEngine's global object from an ABC file.
		 * 
		 * @param hashCode The hash code assigned to the ABC file before compilation.
		 * @param global The global object from a running ABC file.
		 */
		public function updateGlobal(hashCode:String, global:Object):void
		{
			if (hashCode in _loaders)
			{
				// This will get declared global properties (which are 
				// enumerable)
				for (var name:String in global)
				{
					_global[name] = global[name];
				}
				
				// This will get declared global variables (which are not 
				// enumerable)
				var type:XML = describeType(global);
				for each (var variable:XML in type.variable)
				{
					name = variable.@name.toXMLString();
					
					if (!(name in _global))
					{
						// Duplicate "var" declarations are updated as undefined
						// but the corresponding property is properly updated
						// so check if the global object already has it, if it does
						// don't update using the type description
						_global[name] = global[name];
					}
				}
			}
		}
		
		//----------------------------------------------------------------------
		//  
		//  Event Handlers
		//  
		//----------------------------------------------------------------------
		
		/**
		 * @private
		 */
		private function handleComplete(event:Event):void
		{
			try
			{
				_compileStringToBytes = getDefinitionByName("ESC::compileStringToBytes") as Function;
			}
			catch (error:ReferenceError)
			{
				// No definition found because engine is not initiated
			}
			
			dispatchEvent(event);
		}
	}
}