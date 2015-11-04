package spring.boot.trireme;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.context.annotation.ComponentScan;

/**
 * @author oassuncao
 * @since **
 */
@EnableAutoConfiguration
@ComponentScan(basePackages = {"spring.boot.trireme"})
public class SpringBootApplication {
// --------------------------- main() method ---------------------------

    public static void main(String[] args) {
        SpringApplication.run(SpringBootApplication.class, args);
    }
}
