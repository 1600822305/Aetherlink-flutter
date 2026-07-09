package com.example;
public final class Child extends Base implements Runnable {
    private int mFlag;
    public void run() { mFlag = 1; }
}
