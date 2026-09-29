#pragma once

#include <string>

#include <dmuduo/core/buffer.h>
#include <dmuduo/core/eventloop.h>
#include <dmuduo/core/inetaddress.h>
#include <dmuduo/core/tcpconnection.h>
#include <dmuduo/core/tcpserver.h>


// BaseEchoServer 提供一个最小可复用的 echo server 骨架：
// 1. 持有 dmuduo::TcpServer，并完成回调注册与线程数配置。
// 2. 提供默认的连接日志输出与 echo 回显逻辑。
// 3. 允许派生类按需覆写回调，只扩展自己关心的行为。
class BaseEchoServer
{

public:

    // loop 为服务端所属的主 dmuduo::EventLoop。addr/name 直接透传给内部 dmuduo::TcpServer。threadNum 用于设置 subLoop 线程数，默认值保持 demo 行为不变。
    BaseEchoServer(dmuduo::EventLoop *loop, const dmuduo::InetAddress &addr, const std::string &name, int threadNum = 3);

    virtual ~BaseEchoServer() = default;

    // 启动底层 dmuduo::TcpServer。真正的事件分发仍由外部 loop.loop() 驱动。
    void start() { m_server.start(); }


protected:

    // 连接建立/断开回调。默认实现只打印日志，派生类可追加统计或资源管理逻辑。
    virtual void onConnection(const dmuduo::TcpConnectionPtr &conn);

    // 读事件回调。默认行为是把收到的全部数据原样发回去。
    virtual void onMessage(const dmuduo::TcpConnectionPtr &conn, dmuduo::Buffer &buf, const dmuduo::Timestamp &time);

    // 暴露主 loop，方便派生类在特定条件下调度 quit 等操作。
    dmuduo::EventLoop *loop() const { return m_loop; }


private:

    // 这两个中转函数绑定给 dmuduo::TcpServer，目的是把底层回调转发到可覆写的虚函数。

    void handleConnection(const dmuduo::TcpConnectionPtr &conn) { onConnection(conn); }

    void handleMessage(const dmuduo::TcpConnectionPtr &conn, dmuduo::Buffer &buf, const dmuduo::Timestamp &time) { onMessage(conn, buf, time); }

    // dmuduo::TcpServer 负责 accept、连接管理和 IO 事件分发。
    dmuduo::TcpServer m_server;

    // 记录拥有该服务实例的主 loop，生命周期由外部控制。
    dmuduo::EventLoop *m_loop = nullptr;
};
