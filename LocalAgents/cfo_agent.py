"""Helpers for running the CFO agent inside the automation toolkit.

The production code uses pydantic models to describe the response format sent to
OpenAI's `responses` API. The API is strict about JSON Schema validity: every
field declared in `properties` must have a corresponding entry in the
`required` array, and vice‑versa. A recent refactor accidentally removed the
`team_rates` field from the schema while still marking it as required, which
resulted in a 400 response from the API with the message::

    Invalid schema for response_format 'CfoOutput': ... Extra required key
    'team_rates' supplied.

To prevent this regression we rebuild the minimal pieces of the CFO agent in a
self‑contained module and make sure the generated schema always keeps the
`required` list aligned with the declared properties.
"""

from __future__ import annotations

from typing import Any, Dict, List, Sequence, get_args, get_origin

try:  # pragma: no cover - exercised indirectly in tests
    from pydantic import BaseModel, ConfigDict, Field  # type: ignore
except ModuleNotFoundError:  # pragma: no cover
    # The test environment that powers these kata-style exercises does not ship
    # with third-party dependencies.  We provide a very small compatibility
    # layer that mimics the bits of Pydantic v2 we rely on so the models are
    # still usable for schema generation and light validation.  Only the
    # features touched in this module are implemented; the shim is intentionally
    # tiny and easy to audit.
    from dataclasses import MISSING
    from types import NoneType, UnionType
    from typing import Any, Union

    class _FieldSpec:
        __slots__ = ("default", "metadata")

        def __init__(self, default: Any = MISSING, **metadata: Any) -> None:
            self.default = default
            self.metadata = metadata

    def Field(default: Any = MISSING, **metadata: Any) -> _FieldSpec:  # type: ignore
        return _FieldSpec(default, **metadata)

    class ConfigDict(dict):  # type: ignore
        pass

    class _FieldInfo:
        __slots__ = ("annotation", "default", "metadata", "required")

        def __init__(
            self,
            annotation: Any,
            default: Any,
            metadata: Dict[str, Any],
            required: bool,
        ) -> None:
            self.annotation = annotation
            self.default = default
            self.metadata = metadata
            self.required = required

    class _ModelMeta(type):
        def __new__(mcls, name: str, bases: tuple[type, ...], namespace: Dict[str, Any]):
            annotations: Dict[str, Any] = {}
            for base in reversed(bases):
                annotations.update(getattr(base, "__annotations__", {}))
            annotations.update(namespace.get("__annotations__", {}))
            fields: Dict[str, _FieldInfo] = {}

            for attr, annotation in annotations.items():
                if attr.startswith("__") and attr.endswith("__"):
                    continue
                value = namespace.get(attr, MISSING)
                if isinstance(value, _FieldSpec):
                    default = value.default
                    metadata = value.metadata
                else:
                    default = value
                    metadata = {}
                required = default is MISSING
                if isinstance(value, _FieldSpec):
                    if default is MISSING:
                        namespace.pop(attr, None)
                    else:
                        namespace[attr] = default
                fields[attr] = _FieldInfo(annotation, default, metadata, required)

            namespace["__fields__"] = fields
            return super().__new__(mcls, name, bases, namespace)

    class BaseModel(metaclass=_ModelMeta):  # type: ignore
        __fields__: Dict[str, _FieldInfo]

        def __init__(self, **data: Any) -> None:
            for name, info in self.__fields__.items():
                if name in data:
                    setattr(self, name, data[name])
                elif info.required:
                    raise TypeError(f"Missing required field '{name}'")
                elif info.default is not MISSING:
                    setattr(self, name, info.default)
                else:
                    setattr(self, name, None)

        @classmethod
        def _schema_for_annotation(
            cls, annotation: Any, metadata: Dict[str, Any]
        ) -> Dict[str, Any]:
            origin = get_origin(annotation)
            args = get_args(annotation)

            if origin in (list, List, Sequence):
                item_annotation = args[0] if args else Any
                schema = {
                    "type": "array",
                    "items": cls._schema_for_annotation(item_annotation, {}),
                }
                if "min_length" in metadata:
                    schema["minItems"] = metadata["min_length"]
                if "description" in metadata:
                    schema["description"] = metadata["description"]
                return schema

            if origin in (Union, UnionType):
                non_none = [arg for arg in args if arg is not NoneType]
                if non_none and len(non_none) == 1:
                    return cls._schema_for_annotation(non_none[0], metadata)

            if isinstance(annotation, type) and issubclass(annotation, BaseModel):
                schema = annotation.model_json_schema()
                if "description" in metadata:
                    schema.setdefault("description", metadata["description"])
                return schema

            type_mapping: Dict[Any, str] = {str: "string", int: "number", float: "number"}
            schema: Dict[str, Any] = {}
            if annotation in type_mapping:
                schema["type"] = type_mapping[annotation]
            if "description" in metadata:
                schema["description"] = metadata["description"]
            if "ge" in metadata:
                schema["minimum"] = metadata["ge"]
            if "min_length" in metadata and schema.get("type") == "string":
                schema["minLength"] = metadata["min_length"]
            return schema

        @classmethod
        def model_json_schema(cls) -> Dict[str, Any]:
            properties: Dict[str, Any] = {}
            required: List[str] = []
            for name, info in cls.__fields__.items():
                properties[name] = cls._schema_for_annotation(
                    info.annotation, info.metadata
                )
                if info.required:
                    required.append(name)
            schema: Dict[str, Any] = {"type": "object", "properties": properties}
            if required:
                schema["required"] = required
            return schema


class TeamRate(BaseModel):
    """Blended monthly rate for a functional team or role."""

    team: str = Field(..., description="Name of the team or role.")
    headcount: float | None = Field(
        None,
        ge=0,
        description="Number of people allocated to the team (FTE).",
    )
    monthly_cost: float = Field(
        ...,
        ge=0,
        description="Fully-loaded monthly cost for the team in USD.",
    )
    notes: str | None = Field(
        None,
        description="Additional commentary or key assumptions for this rate.",
    )


class BudgetLine(BaseModel):
    """High-level operating cost line item."""

    category: str = Field(..., description="Expense category (e.g. cloud, payroll).")
    monthly_cost: float = Field(..., ge=0, description="Monthly spend in USD.")
    rationale: str = Field(
        ...,
        description="Short explanation justifying the spend or providing context.",
    )


class RunwayScenario(BaseModel):
    """Runway calculation under a specific scenario."""

    scenario: str = Field(..., description="Scenario label such as base or downside.")
    runway_months: float = Field(..., ge=0, description="Resulting runway in months.")
    assumptions: str = Field(
        ...,
        description="Key assumptions behind the scenario (e.g. revenue cadence).",
    )


class Recommendation(BaseModel):
    """Actionable recommendations for the founding team."""

    action: str = Field(..., description="Action item or recommendation summary.")
    owner: str | None = Field(
        None, description="Suggested owner for the action (team or individual)."
    )
    rationale: str = Field(
        ...,
        description="Why the recommendation matters or what risk it mitigates.",
    )


class CfoOutput(BaseModel):
    """Structured response returned by the CFO agent."""

    model_config = ConfigDict(extra="ignore")

    summary: str = Field(
        ...,
        description="Executive-ready summary of the financial position and outlook.",
    )
    budget_lines: List[BudgetLine] = Field(
        ...,
        description="Breakdown of the operating budget by major line item.",
        min_length=1,
    )
    runway_analysis: List[RunwayScenario] = Field(
        ...,
        description="Runway projections under multiple planning scenarios.",
        min_length=1,
    )
    recommendations: List[Recommendation] = Field(
        ...,
        description="Concrete next steps that keep the company on a healthy track.",
        min_length=1,
    )
    team_rates: List[TeamRate] = Field(
        ...,
        description="Per-team blended monthly rates used to build the budget.",
        min_length=1,
    )

    @classmethod
    def model_json_schema(cls, *args: Any, **kwargs: Any) -> dict[str, Any]:
        """Return a schema whose ``required`` list always matches ``properties``.

        OpenAI's response format validation is very strict: the ``required``
        array must list *every* property defined on the object. Pydantic omits
        the key whenever all fields are required, which causes the API to reject
        the schema. We therefore force the list to be present and aligned with
        the actual property keys. The method still delegates to Pydantic to
        perform the heavy lifting so we inherit validation for nested models.
        """

        schema = super().model_json_schema(*args, **kwargs)
        properties = schema.get("properties")
        if isinstance(properties, dict):
            required: List[str] = list(properties.keys())
            schema["required"] = required
        return schema


__all__: Sequence[str] = (
    "BudgetLine",
    "CfoOutput",
    "Recommendation",
    "RunwayScenario",
    "TeamRate",
)
