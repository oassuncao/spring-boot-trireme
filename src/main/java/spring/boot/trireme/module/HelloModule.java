package spring.boot.trireme.module;

import io.apigee.trireme.core.NodeModule;
import io.apigee.trireme.core.NodeRuntime;
import org.mozilla.javascript.Context;
import org.mozilla.javascript.Function;
import org.mozilla.javascript.Scriptable;
import org.mozilla.javascript.ScriptableObject;
import org.mozilla.javascript.annotations.JSFunction;

import java.lang.reflect.InvocationTargetException;

import static io.apigee.trireme.core.ArgUtils.stringArg;

/**
 * @author oassuncao
 * @since **
 */
public class HelloModule implements NodeModule {
// ------------------------ INTERFACE METHODS ------------------------


// --------------------- Interface NodeModule ---------------------

    @Override
    public String getModuleName() {
        return "hello-world";
    }

    @Override
    public Scriptable registerExports(Context context, Scriptable scriptable, NodeRuntime nodeRuntime) throws InvocationTargetException, IllegalAccessException, InstantiationException {
        ScriptableObject.defineClass(scriptable, HelloModuleImpl.class);
        return context.newObject(scriptable, HelloModuleImpl.CLASS_NAME);
    }

// -------------------------- INNER CLASSES --------------------------

    public static class HelloModuleImpl extends ScriptableObject {
        private static final String CLASS_NAME = "_helloModuleClass";

        @JSFunction
        @SuppressWarnings("unused")
        public static String hello(Context cx, Scriptable thisObj, Object[] args, Function func) {
            String name = stringArg(args, 0);
            return "Hello, " + name + '!';
        }

        @Override
        public String getClassName() {
            return CLASS_NAME;
        }
    }
}
