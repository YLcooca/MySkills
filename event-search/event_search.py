#!/usr/bin/env python3
"""
Event Search 原子能力参考库（接口定义）

⚠️ 本文件不是可执行脚本，是 AI Agent 的能力参考。函数速查表在 SKILL.md 中。
请阅读各函数 docstring 获取参数详情、返回值结构、调用示例。

SDK 版本 0.1.4.131，所有签名和参数定义来自源码。
"""

from typing import List, Optional, Union


# ── 枚举常量 ─────────────────────────────────────────────────────────────

# 事件状态码（status 字段）
STATUS_CODES = {
    1: "待上传", 4: "上传中", 5: "数据处理完成", 6: "数据处理失败",
    14: "meta 上报完成", 15: "部分回传", 20: "数据处理中",
}

# 可用标签（available_tags 字段）
AVAILABLE_TAGS = [
    "FILE_BROKEN", "TIMESTAMP_ERROR", "CHANNEL_MISSING", "CALIB_LACK",
    "DOWNLOAD", "VISUALIZATION", "SOC1_NOT_MCAP", "SOC2_NOT_MCAP",
]

# 车辆分组（car_group_list 字段）
CAR_GROUP = {0: "先锋车", 1: "项目车", 2: "用户车"}


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  ENV_SETUP — 必填环境变量（必须在所有 import 之前设置，缺一不可）         ║
# ╚══════════════════════════════════════════════════════════════════════════╝

# Agent 生成代码时，必须在脚本头部完整设置以下 8 个环境变量：
#
#   import os
#   from pathlib import Path
#
#   os.environ["AD_CLOUD_DATASET_CALL_ENV"] = "tjv1"                      # [必填] SDK 环境
#   os.environ["XIAOMI_IAM_ACCESS_KEY_ID"] = "<MCP 获取的 access_key>"    # [必填] MCP 获取
#   os.environ["XIAOMI_IAM_SECRET_ACCESS_KEY"] = "<MCP 获取的 secret_key>"# [必填] MCP 获取
#   os.environ["AD_CLOUD_XIAOMI_DEPARTMENT"] = "<MCP 获取的 cas_dept>"    # [必填] MCP 获取
#   os.environ["XIAOMI_USERNAME"] = "<MCP 获取的 username>"               # [必填] MCP 获取
#   os.environ["EVENT_TYPE"] = "prod"                                      # [必填] prod 或 test
#   os.environ["AD_CLOUD_DATASEEKER_PROXY_ENV"] = "1"                     # [必填] 代理开关
#   os.environ["AD_CLOUD_LOG_DIR"] = str(Path(__file__).parent / "ad_cloud" / "logs")  # [必填] 日志目录
#
#   # 必填校验
#   _REQUIRED = ["XIAOMI_IAM_ACCESS_KEY_ID", "XIAOMI_IAM_SECRET_ACCESS_KEY",
#                "AD_CLOUD_XIAOMI_DEPARTMENT", "XIAOMI_USERNAME"]
#   _missing = [k for k in _REQUIRED if not os.environ.get(k)]
#   if _missing:
#       raise SystemExit(f"❌ 缺少必填环境变量: {', '.join(_missing)}")


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  SDK 导入路径参考                                                         ║
# ╚══════════════════════════════════════════════════════════════════════════╝

# from ad_cloud.event import EventSearcher, seeker
# from ad_cloud.event import ProdEventQueryParam, TESTEventQueryParam, TimeRange
# from ad_cloud.event.models.model import ENVParams
# from ad_cloud.event.enum import FileInfoTypeEnum
# from ad_cloud.event.seeker import download_and_save_by_adrn
# from ad_cloud.event.models.client_models.event_model import QueryReq
# from ad_cloud.event.client.prod_event_client import EventClient
# from ad_cloud.event.client.event_client import EventClient as TestEventClient
# from ad_cloud.utils.logging import logger


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  SDK 类型定义速查                                                         ║
# ╚══════════════════════════════════════════════════════════════════════════╝

# EventSearcher (from ad_cloud.event import EventSearcher)
#   __init__(self, event_id: str, env_params: ENVParams = None)
#   .query_dataclip()          → Adrn
#   .query_event_id()          → List[str]
#   .query_drive_id()          → List[str]
#   .query_session_id()        → List[str]
#   .query_detail()            → EventData
#   .query_detail_with_loc()   → EventData（含位置信息）
#   .download(file_type: FileInfoTypeEnum = RAW_MCAP) → bytes
#   .download_and_save(file_name: str, file_type: FileInfoTypeEnum = RAW_MCAP) → None
#   .async_download_and_save(file_name: str, file_type: FileInfoTypeEnum = RAW_MCAP) → None

# TimeRange (from ad_cloud.event import TimeRange)
#   start_timestamp: Optional[Union[int, str]] = 0
#     int = 纳秒时间戳，如 1701792000000000000
#     str = "YYYY-MM-DD HH:MM:SS"，如 "2024-01-01 00:00:00"
#   end_timestamp:   Optional[Union[int, str]] = 0
#
# 示例：
#   TimeRange(start_timestamp=1701792000000000000, end_timestamp=1702483199000000000)
#   TimeRange(start_timestamp="2024-01-01 00:00:00", end_timestamp="2024-01-08 23:59:59")

# ENVParams (from ad_cloud.event.models.model import ENVParams)
#   AD_CLOUD_DATASET_CALL_ENV:  str  — tjv1 / c3 / nc4 / preview-nc4 / preview-tjv1
#   XIAOMI_IAM_ACCESS_KEY_ID:   str  — IAM AccessKey
#   XIAOMI_IAM_SECRET_ACCESS_KEY: str — IAM SecretKey
#   AD_CLOUD_XIAOMI_DEPARTMENT: str  — 部门，如 "数据平台"
#   XIAOMI_USERNAME:            str  — 用户名（邮箱前缀），如 "chengang5"
#   EVENT_TYPE:                 str  — "prod" 或 "test"

# FileInfoTypeEnum (from ad_cloud.event.enum import FileInfoTypeEnum)
#   RAW_MCAP  = (6, 1)  — MCAP 文件
#   RAW_LOG   = (7, 5)  — LOG 文件
#   RADAR_LOG = (4, -1) — 雷达日志（仅量产）

# ProdEventQueryParam (from ad_cloud.event import ProdEventQueryParam)
#   21 个字段，全量定义见 query_prod_events docstring

# TESTEventQueryParam (from ad_cloud.event import TESTEventQueryParam)
#   17 个字段，全量定义见 query_test_events docstring


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  ATOMIC FUNCTIONS — 原子能力接口                                          ║
# ╚══════════════════════════════════════════════════════════════════════════╝


def query_by_jira_id(jira_id: str) -> Optional[object]:
    """通过 JIRA ID 查询事件，先查量产再查路测。

    参数:
        jira_id: str — JIRA ID，格式 "PROJECT-123456"，示例 "PILOT-749849"

    返回:
        事件对象（含 event_id 等属性），未找到返回 None

    调用示例:
        event = query_by_jira_id("PILOT-749849")
        print(event.event_id)
    """
    ...


def query_by_adrn(adrn: str) -> dict:
    """通过 ADRN 查询索引、可用通道、录制文件信息。

    参数:
        adrn: str — 数据片段 ADRN
              格式 "adr::dataclip:<env>.<cluster>.<seg>::<start_ns>:<end_ns>"
              示例 "adr::dataclip:prod.mo5-mt.0072::1726146648377000000:1726146693023000000"

    返回:
        dict:
          - adrn: str
          - record_files: int — 录制文件数
          - indexes: int — 索引文件数

    调用示例:
        result = query_by_adrn("adr::dataclip:prod.mo5-mt.0072::1726146648377000000:1726146693023000000")
    """
    ...


def query_prod_events(query_param: "ProdEventQueryParam") -> List[str]:
    """查询量产事件。

    ⚠️ 时间范围限制：trigger_time_range 的跨度不得超过 1 天（86400000000000 纳秒）。
    超过 1 天的范围，必须按 1 天切片循环调用本函数，合并所有结果。

    参数:
        query_param: ProdEventQueryParam (from ad_cloud.event import ProdEventQueryParam)
          21 个字段（均为可选，至少填一项）：
          session_uuid:       str                         — 会话 UUID
          session_id:         int                         — 会话 ID
          event_uuid:         str                         — 事件 UUID
          event_id:           int                         — 事件 ID
          extension_key:      str                         — 扩展 key
          event_key:          str                         — 事件类型 key
          car_adrn:           Union[str, List[str]]       — 车辆 ADRN，如 "adr::car:prod:MS11-4:VIN"
          car_model:          Union[str, List[str]]       — 车型，如 "MS11-4"
          car_id:             str                         — 车辆 VID
          car_no:             List[str]                   — 车号列表
          status:             int                         — 状态码（见 STATUS_CODES）
          jira_exist:         Optional[bool]              — True=已创建 JIRA
          available_tags:     List[str]                   — 标签过滤（见 AVAILABLE_TAGS）
          page:               int                         — 页码，默认 1
          size:               int                         — 每页数量，默认 50
          trigger_time_range: Optional[TimeRange]         — 触发时间范围
          update_time_range:  Optional[TimeRange]         — 更新时间范围
          adcode:             str                         — 省市区编码
          car_group_list:     List[int]                   — 车辆类型（见 CAR_GROUP）
          count_limit:        bool                        — False=不限数量, True=最大1W，必填，生成代码的时候默认传 False
          need_loc:           bool                        — 是否需要位置信息，默认 False

    返回:
        List[str] — 当前页的事件 ID 列表

    调用示例:
        from ad_cloud.event import ProdEventQueryParam, TimeRange

        result = seeker.query_prod_event(ProdEventQueryParam(
            car_adrn="adr::car:prod:MS11-4:LVEQU0ECY9F9RCBN7",
            trigger_time_range=TimeRange(
                start_timestamp=1701792000000000000,
                end_timestamp=1702483199000000000,
            ),
            page=1, size=10,
        ))

        result = seeker.query_prod_event(ProdEventQueryParam(
            event_key="EVENT_KEY_DDS_USER_TRIGGER",
            car_model=["MS11-4"],
            trigger_time_range=TimeRange(
                start_timestamp="2024-01-01 00:00:00",
                end_timestamp="2024-01-08 23:59:59",
            ),
            available_tags=["FILE_BROKEN"],
            car_group_list=[0, 1],
            status=5,
        ))
    """
    ...


def count_prod_event(query_param: "ProdEventQueryParam") -> int:
    """查询量产事件总数。

    ⚠️ 时间范围限制同 query_prod_events（不超过 1 天）。

    参数: 同 query_prod_events

    返回: int — 满足条件的事件总数

    调用示例:
        total = seeker.count_prod_event(ProdEventQueryParam(
            car_adrn="adr::car:prod:MS11-4:LVEQU0ECY9F9RCBN7",
            trigger_time_range=TimeRange(start_timestamp=..., end_timestamp=...),
        ))
    """
    ...


def query_test_events(query_param: "TESTEventQueryParam") -> List[str]:
    """查询路测事件。

    ⚠️ 时间范围限制：event_time_range / upload_time_range / etl_time_range 的跨度
    均不得超过 1 天。超过必须按 1 天切片循环调用，合并结果。

    参数:
        query_param: TESTEventQueryParam (from ad_cloud.event import TESTEventQueryParam)
          17 个字段（均为可选，至少填一项）：
          event_name:        str                         — 事件名称
          event_id:          Union[int, List[int]]       — 事件 ID
          drive_id:          int                         — 行程 ID
          session_id:        int                         — 会话 ID
          session_uuid:      str                         — 会话 UUID
          drive_uuid:        str                         — 行程 UUID
          labels:            List[str]                   — 上报规则
          status:            int                         — 状态码（见 STATUS_CODES）
          jira_exist:        Optional[bool]              — True=已创建 JIRA
          event_time_range:  Optional[TimeRange]         — 事件发生时间范围
          upload_time_range: Optional[TimeRange]         — 上传时间范围
          etl_time_range:    Optional[TimeRange]         — ETL 时间范围
          available_tags:    List[str]                   — 事件标签
          car_adrn:          Union[str, List[str]]       — 车辆 ADRN，如 "adr::car:eng:bhd:0085"
          page:              int                         — 页码，默认 1
          size:              int                         — 每页数量，默认 50
          adcode:            str                         — 省市区编码

    返回:
        List[str] — 当前页的事件 ID 列表

    调用示例:
        from ad_cloud.event import TESTEventQueryParam, TimeRange

        result = seeker.query_test_event(TESTEventQueryParam(
            car_adrn="adr::car:eng:bhd:0085",
            event_time_range=TimeRange(
                start_timestamp="2023-12-05 18:20:20",
                end_timestamp="2023-12-06 18:20:20",
            ),
            page=1, size=100,
        ))
    """
    ...


def count_test_event(query_param: "TESTEventQueryParam") -> int:
    """查询路测事件总数。

    ⚠️ 时间范围限制同 query_test_events（不超过 1 天）。

    参数: 同 query_test_events

    返回: int — 满足条件的事件总数

    调用示例:
        total = seeker.count_test_event(TESTEventQueryParam(
            car_adrn="adr::car:eng:bhd:0085",
            event_time_range=TimeRange(start_timestamp="...", end_timestamp="..."),
        ))
    """
    ...


def query_event_detail(event_id: str, env_params: "ENVParams" = None) -> dict:
    """查询事件详情（ADRN / Session ID / Drive ID）。

    参数:
        event_id: str — 事件 ID，如 "11625878214"
        env_params: Optional[ENVParams] — 环境参数，不传则从 os.environ 读取
          ENVParams (from ad_cloud.event.models.model import ENVParams):
            AD_CLOUD_DATASET_CALL_ENV, XIAOMI_IAM_ACCESS_KEY_ID,
            XIAOMI_IAM_SECRET_ACCESS_KEY, AD_CLOUD_XIAOMI_DEPARTMENT,
            XIAOMI_USERNAME, EVENT_TYPE

    返回:
        dict:
          - event_id: str
          - adrn: Adrn — 数据片段 ADRN
          - drive_id: List[str] — 行程 ID
          - session_id: List[str] — 会话 ID
          - detail: EventData — 事件完整详情

    调用示例:
        from ad_cloud.event import EventSearcher
        from ad_cloud.event.models.model import ENVParams

        s = EventSearcher("11625878214", ENVParams(
            AD_CLOUD_DATASET_CALL_ENV="tjv1",
            XIAOMI_IAM_ACCESS_KEY_ID="xxx",
            XIAOMI_IAM_SECRET_ACCESS_KEY="xxx",
            AD_CLOUD_XIAOMI_DEPARTMENT="数据平台",
            XIAOMI_USERNAME="chengang5",
            EVENT_TYPE="prod",
        ))
        adrn = s.query_dataclip()
        detail = s.query_detail()
    """
    ...


def query_event_detail_by_jira(jira_id: str) -> dict:
    """通过 JIRA ID 查询事件详情（先查事件，再查详情）。

    参数:
        jira_id: str — JIRA ID，如 "PILOT-749849"

    返回: 同 query_event_detail

    调用示例:
        result = query_event_detail_by_jira("PILOT-749849")
    """
    ...


def query_detail(event_id: str, env_params: "ENVParams" = None):
    """查询事件完整详情（EventData 对象，不含位置信息）。

    这是查询事件详情的默认方法。query_dataclip / query_session_id / query_drive_id
    内部都调用本方法。如果需要多个字段，直接调本方法一次即可。

    参数:
        event_id: str — 事件 ID
        env_params: Optional[ENVParams] — 同 query_event_detail

    返回: EventData 对象
    """
    ...


def query_detail_with_loc(event_id: str, env_params: "ENVParams" = None):
    """查询事件完整详情（含位置信息，如经纬度）。

    比 query_detail 多返回位置信息。仅在需要位置时调用，否则用 query_detail。

    参数:
        event_id: str — 事件 ID
        env_params: Optional[ENVParams] — 同 query_event_detail

    返回: EventData 对象（含经纬度等位置信息）
    """
    ...


def download_event(
    event_id: str,
    download_path: str,
    file_type: "FileInfoTypeEnum" = None,
    env_params: "ENVParams" = None,
) -> bool:
    """下载事件文件到本地。

    参数:
        event_id: str — 事件 ID
        download_path: str — 本地保存路径（含文件名），如 "/tmp/event.mcap"
        file_type: Optional[FileInfoTypeEnum] — 文件类型，默认 RAW_MCAP
          FileInfoTypeEnum (from ad_cloud.event.enum import FileInfoTypeEnum):
            RAW_MCAP  (6/1)  — MCAP 文件
            RAW_LOG   (7/5)  — LOG 文件
            RADAR_LOG (4/-1) — 雷达日志（仅量产）
        env_params: Optional[ENVParams] — 同 query_event_detail

    返回: bool — True 成功，False 失败

    调用示例:
        from ad_cloud.event.enum import FileInfoTypeEnum
        download_event("11625878214", "/tmp/event.mcap")
        download_event("11625878214", "/tmp/event.log", FileInfoTypeEnum.RAW_LOG)
    """
    ...


def download_by_adrn(adrn: str, download_path: str) -> bool:
    """根据 ADRN 下载原始数据到本地。

    参数:
        adrn: str — 数据片段 ADRN
        download_path: str — 本地保存目录路径

    注意: 调用前需设置 AD_CLOUD_DATASEEKER_PROXY_ENV="1"

    调用示例:
        download_by_adrn("adr::dataclip:prod.mo5-mt.0072::...:...", "/tmp/download")
    """
    ...


def query_available_tags() -> list:
    """查询系统中所有可用标签。

    返回: List[AvailableTagShow] — 标签列表
    """
    ...