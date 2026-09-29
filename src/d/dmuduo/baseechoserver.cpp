#include "baseechoserver.h"

#include <functional>

#include <dlog/core/logger.h>


BaseEchoServer::BaseEchoServer(dmuduo::EventLoop *loop, const dmuduo::InetAddress &addr, const std::string &name, int threadNum)
    : m_server(loop, addr, name), m_loop(loop)
{
    // dmuduo::TcpServer 的回调签名是固定的，这里统一转发到虚函数，
    // 这样基类可以给默认实现，派生类也能只覆写自己需要的部分。
    m_server.setConnectionCallback(std::bind(&BaseEchoServer::handleConnection, this, std::placeholders::_1));
    m_server.setMessageCallback(std::bind(&BaseEchoServer::handleMessage, this, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3));

    // 为 demo 配置一个固定的 IO 线程池大小，和重构前保持一致。
    m_server.setThreadNum(threadNum);
}

void BaseEchoServer::onConnection(const dmuduo::TcpConnectionPtr &conn)
{
    // 这里不做额外状态管理，只保留最基础的连接生命周期日志。
    if (conn->connected())
    {
        DLOG_INFO() << "Connection UP : " << conn->peerAddress().toIpPort();
        return;
    }

    DLOG_INFO() << "Connection DOWN : " << conn->peerAddress().toIpPort();
}

void BaseEchoServer::onMessage(const dmuduo::TcpConnectionPtr &conn, dmuduo::Buffer &buf, const dmuduo::Timestamp &time)
{
    (void)time;

    // dmuduo::Buffer 内部会清空已读数据；这里实现最标准的 echo 行为。
    conn->send(buf.retrieveAllAsString());
}
