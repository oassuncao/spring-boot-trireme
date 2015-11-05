package spring.boot.trireme;

import io.apigee.trireme.core.NodeEnvironment;
import io.apigee.trireme.core.NodeException;
import io.apigee.trireme.core.NodeScript;
import io.apigee.trireme.core.ScriptStatus;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseBody;

import java.io.File;
import java.time.LocalDateTime;
import java.util.concurrent.ExecutionException;

@Controller
public class HomeController {
// ------------------------------ FIELDS ------------------------------

    private static NodeEnvironment node = new NodeEnvironment();

// -------------------------- OTHER METHODS --------------------------

    @RequestMapping("/compile/basic")
    @ResponseBody
    public String compileBasic() throws InterruptedException, NodeException, ExecutionException {
        LocalDateTime dateTime = LocalDateTime.now();
        NodeScript script = node.createScript("basic", new File("/Users/oassuncao/ME/dev/java/spring-boot-trireme/target/classes/node/main.js"), null);
        String result = getResult(script);
        LocalDateTime finishDateTime = LocalDateTime.now();

        long diffInMilli = java.time.Duration.between(dateTime, finishDateTime).toMillis();

        return String.format("Compiled in %d milliseconds", diffInMilli);
    }

    private String getResult(NodeScript nodeScript) throws NodeException, ExecutionException, InterruptedException {
        ScriptStatus status = nodeScript.execute().get();
        if (status.isOk())
            return "Ok";
        return "Error";
    }

    @RequestMapping("/module")
    @ResponseBody
    public String helloModule() throws NodeException, ExecutionException, InterruptedException {
        return runScript("moduleHello",
                "var assert = require('assert');\n" +
                        "var hello = require('hello-world');\n" +
                        "var helloWorld = hello.hello('World');\n" +
                        "console.log(helloWorld);\n" +
                        "assert.equal(helloWorld, 'Hello, World!');\n");
    }

    private String runScript(String name, String script) throws NodeException, ExecutionException, InterruptedException {
        return runScript(name, script, null);
    }

    @RequestMapping("/hello")
    @ResponseBody
    public String helloWord() throws NodeException, ExecutionException, InterruptedException {
        return runScript("helloWorld", "console.log('Hello World!!!');");
    }

    @RequestMapping("/")
    @ResponseBody
    public String home() {
        return "Hello World!";
    }

    private String runScript(String name, String script, String[] args) throws NodeException, ExecutionException, InterruptedException {
        NodeScript nodeScript = node.createScript(name, script, args);
        return getResult(nodeScript);
    }
}
