/*
 * Copyright (c) 2019-2021, salesforce.com, inc.
 * All rights reserved.
 * Licensed under the BSD 3-Clause license.
 * For full license text, see LICENSE.txt file in the repo root  or https://opensource.org/licenses/BSD-3-Clause
*/
package com.sample;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class SampleMain {

  public static void main(String[] args) {
    System.out.println("SampleMain: Launching the sample SpringBoot demo application...");
    StringBuffer sb = new StringBuffer();
    for (String arg : args) {
      sb.append(arg);
      sb.append(" ");
    }
    System.out.println("SampleMain:  Command line args: "+sb.toString());

    SpringApplication.run(SampleMain.class, args);
  }

}
