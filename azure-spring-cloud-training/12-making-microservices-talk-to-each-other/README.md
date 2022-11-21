# 12 - 微服务间的相互调用

**本教程是[Azure Spring Cloud 培训](../README.md)系列之一**


创建与其他微服务通讯的微服务。

---

在[第6节](../06-build-a-reactive-spring-boot-microservice-using-cosmos/README.md)我们部署了一个微服务，返回一个城市列表。在[第7节](../07-build-a-spring-boot-microservice-using-mysql/README.md)，我们部署了一个微型服务，给一个城市，返回该城市的天气。并在[第9节](../09-putting-it-all-together-a-complete-microservice-stack/README.md)，我们创建了一个前端应用程序，来调用这两个微服务。

这种设计效率明显低下：浏览器首先调用`city-service`，等待它响应，并在得到该响应后，再基于每个城市调用`weather-service`获得返回。所有这些远程调用都是通过公共互联网进行的，其访问速度很难得到保证。

为了改进这种低效率，我们将创建一个入口的微服务，实现[交易脚本](https://www.martinfowler.com/eaaCatalog/transactionScript.html)模式：它将协调各个微服务的调用，并返回所有城市的天气。为此，我们将使用[Spring Cloud OpenFeign]. OpenFeign 将从Spring Cloud Registry自动获取调用的微服务的地址，从而方便我们构建微服务`all-cities-weather-services`，无需关心其他微服务的位置。

请注意，我们在本节中创建的代码是适用于任意endpoint的。我们需要指定的就是在`@FeignClient`的注解。然后，OpenFeign 和Spring Cloud Registry 在幕后合作，将我们的新微服务连接到之前创建的服务。

## 创建Spring Boot微服务

我们从命令行调用Spring Initalizer服务为来创建新的微服务：

```bash
curl https://start.spring.io/starter.tgz -d dependencies=cloud-feign,web,cloud-eureka,cloud-config-client -d baseDir=all-cities-weather-service -d bootVersion=2.3.8 -d javaVersion=1.8 | tar -xzvf -
```

## 添加Spring代码调用其他微服务

在`DemoApplication`类同一目录下，创建一个`Weather`类：

```java
package com.example.demo;

public class Weather {

    private String city;

    private String description;

    private String icon;

    public String getCity() {
        return city;
    }

    public void setCity(String city) {
        this.city = city;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getIcon() {
        return icon;
    }

    public void setIcon(String icon) {
        this.icon = icon;
    }
}
```

注意：这是跟我们在第7节创建的类`Weather`是基本一样的，与我们原来在`weather-service`定义的有一个唯一的区别是：我们不再将该类注释为用于数据检索的JPA实体。

接下来，在同一位置创建`City`类。这与我们在第6节创建的类`City`是基本一样的。

```java
package com.example.demo;

public class City {

    private String name;

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }
}
```

然后，在同一位置创建一个名为`CityServiceClient`的接口类，内容如下。当我们运行新服务时，OpenFeign 将自动为此接口提供实现。

```java
package com.example.demo;

import java.util.List;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;

@FeignClient("city-service")
public interface CityServiceClient{

    @GetMapping("/cities")
    List<List<City>> getAllCities();
}

```

为weather-service创建一个类似的 OpenFeign 客户端接口，命名为`WeatherServiceClient`.

```java
package com.example.demo;

import com.example.demo.Weather;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;


@FeignClient("weather-service")
@RequestMapping("/weather")
public interface WeatherServiceClient{

    @GetMapping("/city")
    Weather getWeatherForCity(@RequestParam("name") String cityName);
}

```

要使 Spring Cloud 能够发现基础服务并自动生成 OpenFeign 客户端，需要在`DemoApplication`类添加注释 @EnableDiscoveryClient 和 @EnableFeignClients，（以及相应的`import`声明）：

```java
package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.cloud.openfeign.EnableFeignClients;

@SpringBootApplication
@EnableDiscoveryClient
@EnableFeignClients
public class DemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}
```

现在一切都就位了，可以开始实现`all-cities-weather-service`. 创建类`AllCitiesWeatherController`如下：

```java
package com.example.demo;

import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import com.example.demo.City;
import com.example.demo.CityServiceClient;
import com.example.demo.Weather;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class AllCitiesWeatherController {

    @Autowired
    private CityServiceClient cityServiceClient;

    @Autowired 
    private WeatherServiceClient weatherServiceClient;

    @GetMapping("/")
    public List<Weather> getAllCitiesWeather(){
        Stream<City> allCities = cityServiceClient.getAllCities().stream().flatMap(list -> list.stream());

        //Obtain weather for all cities in parallel
        List<Weather> allCitiesWeather = allCities.parallel()
            .peek(city -> System.out.println("City: >>"+city.getName()+"<<"))
            .map(city -> weatherServiceClient.getWeatherForCity(city.getName()))
            .collect(Collectors.toList());

        return allCitiesWeather;
    }
}
```

## 添加超时设置

为了阻止 Feign 服务自动超时，请打开`src/main/resources/application.properties`文件并添加：

```properties
feign.client.config.default.connectTimeout=160000000
feign.client.config.default.readTimeout=160000000
```

## 在Azure Spring Cloud上创建应用程序

和以前一样，创建一个特定的`all-cities-weather-service`应用在您的Azure Spring Cloud实例中：

```bash
az spring-cloud app create -n all-cities-weather-service
```

## 部署应用程序

现在，您可以编译您的"all-cities-weather-service"项目，并将其发送到 Azure Spring Cloud中：

```bash
cd all-cities-weather-service
./mvnw clean package -DskipTests
az spring-cloud app deploy -n all-cities-weather-service --jar-path target/demo-0.0.1-SNAPSHOT.jar
cd ..
```

## 在云中测试项目

您可以使用第 8 节中创建的网关直接访问全城市天气服务。

> 💡**注意：**尾随斜线（`/`）是必须的。

```bash
https://<Your gateway URL>/ALL-CITIES-WEATHER-SERVICE/
```

您应该获得 JSON 输出与所有城市的天气：

```json
[{"city":"Paris, France","description":"It's always sunny on Azure Spring Cloud","icon":"weather-sunny"},
{"city":"London, UK","description":"It's always sunny on Azure Spring Cloud","icon":"weather-sunny"}]
```

---

⬅️上一个教程：[11 - 配置 CI/CD](../11-configure-ci-cd/README.md)

➡️下一个教程：[总结](../99-conclusion/README.md)
